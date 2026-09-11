#!/usr/bin/env python3
"""Create a verified copy/literal binary patch, reusing unchanged PCK resources.

The base MUST be the exact published executable, never a rebuilt old tag. The
client verifies base, archive and reconstructed target SHA-256 independently.
No external patch executable is required by the client.
"""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile
import struct
from audit_build_size import audit

CHUNK = 65536

def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def regions(path):
    """Include engine, packed files, alignment gaps, pack directory and trailer."""
    size = path.stat().st_size
    try:
        entries = sorted(audit(path, verify=True)['entries'], key=lambda item: item['offset'])
    except (ValueError, OSError, UnicodeError, struct.error):
        return [(0, size)]
    spans, cursor = [], 0
    for item in entries:
        start, length = item['offset'], item['bytes']
        if not length:
            continue
        if start < cursor:
            raise ValueError('Overlapping PCK resources')
        if start > cursor:
            spans.append((cursor, start - cursor))
        spans.append((start, length))
        cursor = start + length
    if cursor < size:
        spans.append((cursor, size - cursor))
    return spans

def make_delta(base, target, helper, output):
    base, target, helper, output = map(Path, (base, target, helper, output))
    lookup = {}
    with base.open('rb') as stream:
        for start, size in regions(base):
            stream.seek(start)
            position = start
            while size:
                block = stream.read(min(CHUNK, size))
                lookup.setdefault((len(block), hashlib.sha256(block).digest()), position)
                size -= len(block)
                position += len(block)
    operations = []
    copied = 0
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        with archive.open('payload.bin', 'w', force_zip64=True) as literals, target.open('rb') as stream:
            for start, size in regions(target):
                stream.seek(start)
                while size:
                    block = stream.read(min(CHUNK, size))
                    size -= len(block)
                    offset = lookup.get((len(block), hashlib.sha256(block).digest()))
                    if offset is None:
                        literals.write(block)
                        if operations and 'copy' not in operations[-1]:
                            operations[-1]['size'] += len(block)
                        else:
                            operations.append({'size': len(block)})
                    else:
                        copied += len(block)
                        if operations and operations[-1].get('copy', -1) >= 0 and operations[-1]['copy'] + operations[-1]['size'] == offset:
                            operations[-1]['size'] += len(block)
                        else:
                            operations.append({'copy': offset, 'size': len(block)})
        plan = dict(format=1, base_sha256=digest(base), target_sha256=digest(target),
                    target_size=target.stat().st_size, ops=operations)
        if len(operations) > 100000:
            raise ValueError('Too many delta operations')
        archive.writestr('delta.json', json.dumps(plan, separators=(',', ':')))
        archive.write(helper, helper.name)
    return dict(copied_bytes=copied, target_bytes=target.stat().st_size,
                patch_bytes=output.stat().st_size, operations=len(operations))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['base', 'target', 'helper', 'output']:
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(make_delta(args.base, args.target, args.helper, args.output)))
