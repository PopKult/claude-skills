# PopKult agent skills

The six canonical skills live in skills/<name>/SKILL.md; shared development
instructions live in references/development-workflow.md. Read the relevant skill
before editing its workflow. Keep instructions portable across Codex, Cursor and
Claude Code; the existing .claude-plugin manifest remains a compatibility wrapper.

Use feature branches, preserve user work, and complete the agreed scope without
per-commit approval pauses. Push/open PRs when requested; do not merge them.
Keep production promote/abort authorization explicit. Keep juicer-harvest-content
at exactly 2 forward + 1 backward tasks per phrase and preserve its phrase-list
review step. Juicer's docs link to this canonical version.

Checks: python3 scripts/check-skills.py. For changed helpers, exercise actual
behavior using temporary files/directories; no live cluster or credentials needed.
Keep install paths overridable and refuse to overwrite unrelated existing files.
Never commit machine-specific installed links or credentials.
