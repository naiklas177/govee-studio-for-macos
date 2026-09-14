#!/usr/bin/env python3
"""Inspect staged blobs without printing matched secret values. No network or Keychain access."""
import hashlib
import json
import pathlib
import re
import subprocess
import sys


def git(*args):
    return subprocess.check_output(['git', *args])


def main():
    root = git('rev-parse', '--show-toplevel').decode().strip()
    import os
    os.chdir(root)
    paths = git('diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z').decode().split('\0')
    paths = [p for p in paths if p]
    if not paths:
        print('No staged files to check. Stage the intended publication first.')
        return 1
    blocked_dirs = {'.local', '.build', 'dist', '.swiftpm'}
    blocked_names = {'workspace.json', 'recovery.json', 'show.json', 'room-music.json',
                     'room-scenes.json', 'govee-scenes.json', 'govee-music-profiles.json'}
    patterns = {
        'literal UUID / possible API credential': r'\b[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}\b',
        'GitHub token': r'\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})',
        'private key block': r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
        'private LAN address': r'\b(?:192\.168\.\d{1,3}\.\d{1,3}|10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})\b',
        'MAC / device address': r'\b(?:[0-9A-Fa-f]{2}:){5,7}[0-9A-Fa-f]{2}\b',
        'absolute personal home path': r'/Users/[A-Za-z0-9_.-]+/',
    }
    findings = []
    try:
        media = json.loads(git('show', ':docs/media/manifest.json'))['sha256']
    except (subprocess.CalledProcessError, KeyError, ValueError):
        media = {}

    for name in paths:
        path = pathlib.PurePosixPath(name)
        if blocked_dirs.intersection(path.parts) or path.name in blocked_names or path.name.startswith('.env') or path.suffix in {'.zip', '.key', '.pem', '.p12', '.log'}:
            findings.append(f'{name}: private/generated path')
            continue
        data = git('show', ':' + name)
        if path.parent == pathlib.PurePosixPath('docs/media') and path.suffix in {'.png', '.gif', '.mp4'}:
            if media.get(path.name) == hashlib.sha256(data).hexdigest():
                continue
            findings.append(f'{name}: media checksum absent or changed; review required')
            continue
        if b'\0' in data:
            findings.append(f'{name}: binary requires explicit manual review')
            continue
        text = data.decode('utf-8', errors='replace')
        for label, pattern in patterns.items():
            if re.search(pattern, text):
                findings.append(f'{name}: {label}')
    if findings:
        print('\n'.join(findings))
        print('Publication check failed. Values intentionally omitted.')
        return 1
    print(f'Checked {len(paths)} staged files (including checksum-reviewed media): no flagged credentials, device identifiers or private paths.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
