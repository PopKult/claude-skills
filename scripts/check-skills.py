#!/usr/bin/env python3
"""Check portable skill metadata, Markdown links and bundled script syntax."""
import ast
from pathlib import Path
import re
import subprocess
import sys


def main():
    root = Path(__file__).resolve().parents[1]
    errors = []
    skills = sorted((root / 'skills').glob('*/SKILL.md'))
    for path in skills:
        text = path.read_text()
        parts = text.split('---', 2)
        if len(parts) != 3 or parts[0].strip():
            errors.append(f'{path}: missing YAML frontmatter')
            continue
        fields = dict(re.findall(r'^(name|description):\s*(.+)$', parts[1], re.M))
        if fields.get('name') != path.parent.name:
            errors.append(f'{path}: name must match its directory')
        if not fields.get('description', '').strip():
            errors.append(f'{path}: missing description')
    for path in [root / 'README.md', root / 'AGENTS.md', *skills,
                 *sorted((root / 'references').glob('*.md'))]:
        text = path.read_text()
        for dest in re.findall(r'\[[^\]]+\]\(([^\s)]+)\)', text):
            if '://' in dest or dest.startswith('#'):
                continue
            dest = dest.split('#', 1)[0]
            if not (path.parent / dest).exists():
                errors.append(f'{path.relative_to(root)}: missing reference {dest}')
    for path in sorted(root.rglob('*')):
        if '.git' in path.parts:
            continue
        if path.suffix == '.py':
            try:
                ast.parse(path.read_text(), filename=str(path))
            except SyntaxError as exc:
                errors.append(str(exc))
        elif path.suffix == '.sh':
            result = subprocess.run(['bash', '-n', str(path)], capture_output=True, text=True)
            if result.returncode:
                errors.append(result.stderr.strip())
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print(f'OK: {len(skills)} skills; local references and script syntax valid')
    return 0


if __name__ == '__main__':
    sys.exit(main())
