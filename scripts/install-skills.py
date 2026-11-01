#!/usr/bin/env python3
"""Link this checkout's skills into the shared local Agent Skills directory."""
import argparse
from pathlib import Path
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', type=Path, default=Path.home() / '.agents/skills')
    args = parser.parse_args()
    target = args.target.expanduser().absolute()
    source = Path(__file__).resolve().parents[1] / 'skills'
    skills = sorted(p for p in source.iterdir() if (p / 'SKILL.md').is_file())
    if not skills:
        parser.error(f'No skills found in {source}')
    # Check every destination before creating anything; preserve foreign installs.
    if target.exists() and not target.is_dir():
        parser.error(f'Target is not a directory: {target}')
    conflicts = []
    for skill in skills:
        link = target / skill.name
        if link.is_symlink() and link.resolve() == skill.resolve():
            continue
        if link.exists() or link.is_symlink():
            conflicts.append(str(link))
    if conflicts:
        parser.error('Refusing to replace existing paths:\n' + '\n'.join(conflicts))
    try:
        target.mkdir(parents=True, exist_ok=True)
        for skill in skills:
            link = target / skill.name
            if link.is_symlink():
                print(f'Already installed: {link}')
            else:
                link.symlink_to(skill, target_is_directory=True)
                print(f'Installed: {link} -> {skill}')
    except OSError as exc:
        print(f'Installation failed: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
