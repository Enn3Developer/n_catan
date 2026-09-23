#!/usr/bin/env python3
"""Report actual resources in a Godot PCK or self-contained executable (PCK v2–4).

The pack directory format follows Godot's core/io/file_access_pack.cpp.
Reads packed .import files so reports name source assets, not hashed cache files.
"""
import argparse
import collections
import hashlib
import json
import struct
from pathlib import Path


def audit(path, verify=False):
    length = path.stat().st_size
    with path.open('rb') as stream:
        def read(fmt):
            return struct.unpack('<' + fmt, stream.read(struct.calcsize('<' + fmt)))

        if stream.read(4) == b'GDPC':
            start, pack_size = 0, length
        else:
            stream.seek(-12, 2)
            pack_size, magic = read('QI')
            if magic != 0x43504447:
                raise ValueError('No embedded PCK trailer found')
            start = length - 12 - pack_size
        stream.seek(start)
        magic, version, major, minor, patch, flags, base = read('6IQ')
        if magic != 0x43504447 or version not in (2, 3, 4) or flags & ~2:
            raise ValueError('Expected an unencrypted, non-sparse Godot PCK v2–4')
        if version >= 3 or flags & 2:
            base += start
        if version >= 3:
            directory, = read('Q')
            stream.seek(start + directory)
        else:
            stream.read(64)
        count, = read('I')
        entries = []
        for _ in range(count):
            name_size, = read('I')
            name = stream.read(name_size).rstrip(b'\0').decode().removeprefix('res://')
            offset, size = read('QQ')
            digest = stream.read(16).hex()
            file_flags, = read('I')
            if file_flags or not 0 <= base + offset <= base + offset + size <= length:
                raise ValueError(f'Unsupported or invalid file entry: {name}')
            entries.append(dict(path=name, offset=base + offset, bytes=size, md5=digest))

        sources = {}
        import re
        for entry in entries:
            if entry['path'].endswith('.import'):
                stream.seek(entry['offset'])
                config = stream.read(entry['bytes']).decode()
                for dest in re.findall(r'res://\.godot/imported/[^"\n]+', config):
                    sources[dest.removeprefix('res://')] = entry['path'].removesuffix('.import')
            if verify:
                stream.seek(entry['offset'])
                digest = hashlib.md5(stream.read(entry['bytes'])).hexdigest()
                if digest != entry['md5']:
                    raise ValueError(f'Checksum mismatch: {entry["path"]}')

        groups = collections.Counter()
        for entry in entries:
            source = sources.get(entry['path'], entry['path'])
            entry['source'] = source
            if source.startswith('assets/materials/runtime/'):
                category = 'Runtime textures (' + source.split('/')[3] + ' px)'
            elif source.startswith('assets/materials/') and source.endswith(('.jpg', '.import')):
                category = 'Unused authoring textures'
            elif source.startswith('assets/premium/'):
                category = 'Biome models'
            elif source.startswith('assets/audio/'):
                category = 'Audio'
            else:
                category = 'Other resources'
            groups[category] += entry['bytes']
    return dict(file=path.name, bytes=length, engine_bytes=start, pack_bytes=pack_size,
                engine_version=f'{major}.{minor}.{patch}', resource_count=count,
                categories=dict(groups.most_common()), entries=entries)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('build', type=Path)
    parser.add_argument('--json', type=Path, help='Write the full resource inventory')
    parser.add_argument('--verify', action='store_true', help='Check every packed file checksum')
    parser.add_argument('--max-mib', type=int, help='Reject builds above this size in MiB')
    args = parser.parse_args()
    if args.max_mib is not None and args.max_mib <= 0:
        parser.error('--max-mib must be positive')
    result = audit(args.build, args.verify)
    mib = 1024 ** 2
    print(f'{result["bytes"] / mib:.2f} MiB total; {result["engine_bytes"] / mib:.2f} MiB engine; '
          f'{result["resource_count"]} packed resources')
    for group, size in result['categories'].items():
        print(f'  {size / mib:8.2f} MiB  {group}')
    if args.verify:
        print('All packed resource checksums verified.')
    if args.json:
        args.json.write_text(json.dumps(result, indent=2) + '\n')
    if args.max_mib is not None and result['bytes'] > args.max_mib * mib:
        parser.exit(1, f'Export rejected: {result["bytes"] / mib:.2f} MiB exceeds the '
                    f'{args.max_mib} MiB release limit. Check the Linux exclusion filters '
                    'in export_presets.cfg; see docs/build-size.md.\n')


if __name__ == '__main__':
    main()
