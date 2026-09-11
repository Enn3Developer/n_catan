#!/usr/bin/env python3
"""Build signed release packages; reuse only verified, exact published binaries."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.request
import zipfile
from make_delta import make_delta, digest

ROOT = Path(__file__).resolve().parents[1]
CONFIG = json.loads((ROOT / 'config/release.json').read_text())
REPO = CONFIG['repository']
PLATFORMS = {'linux-x86_64': ('linux', 'N Catan.x86_64', 'n-catan-updater'),
             'windows-x86_64': ('win', 'N Catan.exe', 'n-catan-updater.exe')}


def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def gh(*args):
    return subprocess.check_output(['gh', *args], text=True)


def version(tag):
    match = re.fullmatch(r'v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?', tag)
    if not match or any(int(n) > 65535 for n in match.groups()[:3]):
        raise ValueError('Tag must be a SemVer such as v1.2.3 (components <= 65535)')
    if match[4] and any(p.isdigit() and len(p) > 1 and p[0] == '0' for p in match[4].split('.')):
        raise ValueError('Leading zero in numeric prerelease')
    return '.'.join(match.groups()[:3]) + '.0'


def stamp(tag):
    numeric = version(tag)
    path = ROOT / 'scripts/build_info.gd'
    path.write_text(re.sub(r'const VERSION\s*:?=\s*".*"', f'const VERSION="{tag}"', path.read_text()))
    path = ROOT / 'project.godot'
    text = path.read_text()
    text = re.sub(r'^config/version=.*\n', '', text, flags=re.M)
    path.write_text(text.replace('[application]\n', f'[application]\n\nconfig/version="{tag}"\n'))
    path = ROOT / 'export_presets.cfg'
    path.write_text(re.sub(r'(application/(?:file|product)_version)=.*', rf'\1="{numeric}"', path.read_text()))


def verify_manifest(path):
    envelope = json.loads(Path(path).read_bytes())
    payload = base64.b64decode(envelope['payload'], validate=True)
    signature = base64.b64decode(envelope['signature'], validate=True)
    with tempfile.TemporaryDirectory() as temp:
        temp = Path(temp)
        (temp / 'payload').write_bytes(payload)
        (temp / 'signature').write_bytes(signature)
        run('openssl', 'dgst', '-sha256', '-verify', str(ROOT / 'updater/update_public.pem'),
            '-signature', str(temp / 'signature'), str(temp / 'payload'), stdout=subprocess.DEVNULL)
    manifest = json.loads(payload)
    version(manifest['version'])
    if manifest['format'] != 1 or manifest['repository'] != REPO:
        raise ValueError('Wrong manifest repository/format')
    return manifest


def spec(path):
    return {'name': path.name, 'size': path.stat().st_size, 'sha256': digest(path)}


def bootstrap():
    dest = ROOT / 'build/godot'
    dest.mkdir(parents=True, exist_ok=True)
    for kind in ['editor', 'templates']:
        name = CONFIG[f'godot_{kind}_asset']
        path = dest / name
        if not path.exists() or digest(path) != CONFIG[f'godot_{kind}_sha256']:
            urllib.request.urlretrieve(f'https://github.com/godotengine/godot-builds/releases/download/{CONFIG["godot_version"]}/{name}', path)
        if digest(path) != CONFIG[f'godot_{kind}_sha256']:
            raise ValueError(f'Godot {kind} checksum mismatch')
        with zipfile.ZipFile(path) as archive:
            if kind == 'editor':
                executable = dest / name.removesuffix('.zip')
                executable.write_bytes(archive.read(executable.name))
                executable.chmod(0o755)
            else:
                target = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))) / 'godot/export_templates' / CONFIG['godot_version'].replace('-', '.')
                target.mkdir(parents=True, exist_ok=True)
                for filename in ['linux_release.x86_64', 'windows_release_x86_64.exe']:
                    (target / filename).write_bytes(archive.read('templates/' + filename))
    print(executable)


def previous(tag, directory):
    releases = json.loads(gh('api', f'repos/{REPO}/releases?per_page=30'))
    for release in releases:
        if release['draft'] or release['prerelease'] or release['tag_name'] == tag:
            continue
        if not any(a['name'] == 'update-manifest.json' for a in release['assets']):
            continue
        try:
            gh('release', 'download', release['tag_name'], '--repo', REPO, '--pattern', 'update-manifest.json', '--dir', str(directory), '--clobber')
            manifest = verify_manifest(directory / 'update-manifest.json')
            if manifest['version'] != release['tag_name']:
                raise ValueError('Previous tag/manifest mismatch')
            return manifest
        except (subprocess.CalledProcessError, ValueError, KeyError) as error:
            print(f'Skipping unusable previous release: {error}')
    return None


def package(tag, key, commit, with_previous=True):
    version(tag)
    if not re.fullmatch('[0-9a-f]{40}', commit):
        raise ValueError('Expected full commit SHA')
    out = ROOT / 'dist' / tag
    out.mkdir(parents=True, exist_ok=True)
    protocol = int(re.search(r'const PROTOCOL\s*:?=\s*(\d+)', (ROOT / 'scripts/build_info.gd').read_text())[1])
    manifest = dict(format=1, version=tag, protocol=protocol, repository=REPO, commit=commit, platforms={})
    with tempfile.TemporaryDirectory() as temp:
        temp = Path(temp)
        base_manifest = previous(tag, temp) if with_previous else None
        for platform, (folder, game, helper) in PLATFORMS.items():
            source = ROOT / 'build' / folder
            full = out / f'n-catan-{tag}-{platform}.zip'
            with zipfile.ZipFile(full, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
                for name in [game, helper, 'README.txt', 'LICENSE']:
                    archive.write(source / name, name)
            data = dict(game=spec(source / game), updater=spec(source / helper), full=spec(full), deltas=[])
            if base_manifest and platform in base_manifest['platforms']:
                try:
                    old = base_manifest['platforms'][platform]
                    name = old['full']['name']
                    if Path(name).name != name or '..' in name:
                        raise ValueError('Unsafe base archive name')
                    gh('release', 'download', base_manifest['version'], '--repo', REPO, '--pattern', name, '--dir', str(temp), '--clobber')
                    if spec(temp / name) != old['full']:
                        raise ValueError('Previous archive checksum mismatch')
                    base = temp / game
                    with zipfile.ZipFile(temp / name) as archive:
                        info = archive.getinfo(game)
                        if info.file_size != old['game']['size'] or info.file_size > 1 << 30:
                            raise ValueError('Previous executable size mismatch')
                        with archive.open(info) as src, base.open('wb') as dst:
                            import shutil
                            shutil.copyfileobj(src, dst)
                    if spec(base) != old['game']:
                        raise ValueError('Previous executable checksum mismatch')
                    patch = out / f'n-catan-{base_manifest["version"]}-to-{tag}-{platform}.delta.zip'
                    stats = make_delta(base, source / game, source / helper, patch)
                    print(platform, stats)
                    if patch.stat().st_size < full.stat().st_size * .85:
                        data['deltas'].append(dict(from_version=base_manifest['version'], base_sha256=digest(base), asset=spec(patch)))
                    else:
                        patch.unlink()
                except (subprocess.CalledProcessError, ValueError, KeyError, OSError, zipfile.BadZipFile) as error:
                    print(f'{platform}: full package only: {error}')
            manifest['platforms'][platform] = data
        payload = json.dumps(manifest, sort_keys=True, separators=(',', ':')).encode()
        raw = temp / 'payload'
        raw.write_bytes(payload)
        sig = subprocess.check_output(['openssl', 'dgst', '-sha256', '-sign', str(key), str(raw)])
        envelope = dict(payload=base64.b64encode(payload).decode(), signature=base64.b64encode(sig).decode())
        signed = out / 'update-manifest.json'
        signed.write_text(json.dumps(envelope, separators=(',', ':')) + '\n')
        verify_manifest(signed)
    (out / 'SHA256SUMS').write_text(''.join(f'{digest(p)}  {p.name}\n' for p in sorted(out.iterdir()) if p.is_file() and p.name != 'SHA256SUMS'))
    print(out)


def completed(tag, commit):
    result = subprocess.run(['gh', 'release', 'view', tag, '--repo', REPO, '--json', 'assets'], capture_output=True, text=True)
    if result.returncode:
        return False
    if not any(a['name'] == 'update-manifest.json' for a in json.loads(result.stdout)['assets']):
        return False
    with tempfile.TemporaryDirectory() as temp:
        gh('release', 'download', tag, '--repo', REPO, '--pattern', 'update-manifest.json', '--dir', temp)
        manifest = verify_manifest(Path(temp) / 'update-manifest.json')
    if manifest['version'] != tag or manifest['commit'] != commit:
        raise ValueError('Completed release has a different commit; tags are immutable')
    return True


def publish(tag, commit):
    if completed(tag, commit):
        # Finish a draft if a prior run stopped after uploading the manifest.
        gh('release', 'edit', tag, '--repo', REPO, '--draft=false', '--prerelease=' + ('true' if '-' in tag else 'false'))
        print('Signed release already complete')
        return
    existing = subprocess.run(['gh', 'release', 'view', tag, '--repo', REPO], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    if not existing:
        gh('release', 'create', tag, '--repo', REPO, '--verify-tag', '--draft', '--title', tag, '--generate-notes')
    out = ROOT / 'dist' / tag
    assets = [str(p) for p in sorted(out.iterdir()) if p.name != 'update-manifest.json']
    gh('release', 'upload', tag, '--repo', REPO, '--clobber', *assets)
    # Clients discover a release only after every package is uploaded.
    gh('release', 'upload', tag, '--repo', REPO, str(out / 'update-manifest.json'))
    gh('release', 'edit', tag, '--repo', REPO, '--draft=false', '--prerelease=' + ('true' if '-' in tag else 'false'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['bootstrap', 'stamp', 'package', 'publish', 'check'])
    parser.add_argument('--tag')
    parser.add_argument('--commit')
    parser.add_argument('--key', type=Path)
    parser.add_argument('--no-previous', action='store_true')
    args = parser.parse_args()
    if args.command == 'bootstrap':
        bootstrap()
    else:
        version(args.tag)
        if args.command == 'stamp':
            stamp(args.tag)
        elif args.command == 'package':
            package(args.tag, args.key, args.commit, not args.no_previous)
        elif args.command == 'publish':
            publish(args.tag, args.commit)
        else:
            done = completed(args.tag, args.commit)
            if done:
                done = not json.loads(gh('release', 'view', args.tag, '--repo', REPO, '--json', 'isDraft'))['isDraft']
            with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
                output.write(f'complete={str(done).lower()}\n')
