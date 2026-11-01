# PopKult Agent Skills

Shared Agent Skills for Codex, Cursor and Claude Code. The GitHub repository
keeps its existing name `PopKult/claude-skills` so existing clones and plugin
installations keep working. Each skill has one source under skills/.

| Skill | Use |
|---|---|
| [init-service](skills/init-service/SKILL.md) | Scaffold, register and implement a new Go service |
| [init-frontend](skills/init-frontend/SKILL.md) | Create a React/GraphQL operator frontend |
| [add-feature](skills/add-feature/SKILL.md) | Extend an existing Go service or admin frontend |
| [add-mobile-feature](skills/add-mobile-feature/SKILL.md) | Extend the KMM application |
| [canary-release](skills/canary-release/SKILL.md) | Inspect and promote/abort a production canary with explicit authorization |
| [juicer-harvest-content](skills/juicer-harvest-content/SKILL.md) | Generate content with **2 forward + 1 backward** tasks per phrase |

## Install for local Codex and Cursor

From this checkout:

```bash
python3 scripts/install-skills.py
```

This links each skill into ~/.agents/skills/ and preserves its bundled scripts
and relative references. Existing unrelated skills/files are never overwritten;
conflicts are reported before making changes. Running it again is safe. Moving
this checkout requires reinstalling after removing the old links explicitly.
Restart/reload the agent session after installation. Local home-directory links
are for local agents; cloud/remote agents need their own checkout and installation.

For a project-scoped installation use an absolute target:

```bash
python3 scripts/install-skills.py --target /path/to/repo/.agents/skills
```

Keep machine-specific links out of git. For a shared/cloud setup vendor skills
under .agents/skills/ and the shared references under .agents/references/ together,
or install from this repository in that environment. When following links from
an installed symlink, resolve its real source path first. A clone in a sibling folder is not discovered automatically.

Codex supports explicit $add-feature invocation; Cursor offers /add-feature in
Agent chat. Both can also select skills by their descriptions. Always-on repository
guidance belongs in each repo's AGENTS.md, not in a manually invoked skill.

Official references: [Codex skills](https://learn.chatgpt.com/docs/build-skills),
[Cursor skills](https://cursor.com/docs/skills),
[repository guidance](https://learn.chatgpt.com/docs/customization/overview).

## Claude Code compatibility

The existing .claude-plugin/plugin.json and skills/ layout remain available.
Use your existing Claude Code plugin installation pointed at this repository.
Instructions no longer require Claude's Skill tool or a provider-specific namespace.

## Workflow and maintenance

Development skills share [development-workflow.md](references/development-workflow.md):
feature branches, coherent commits, relevant checks and completion of the agreed
scope without per-commit approval pauses. Push/PR work follows the user's request;
production actions keep their explicit authorization boundary. The harvester keeps
its phrase-list review before batch generation.

Edit the canonical harvester here. Juicer's docs link here instead of maintaining
another implementation. Its import accepts multi-word gloss chunks and assigns
fresh server IDs. The validator checks JSON shape and coverage; linguistic quality
and grounded phrase selection still need review.

Run python3 scripts/check-skills.py and python3 -m unittest discover -s tests -v
before opening a PR. It validates skill
metadata, local Markdown references and bundled script syntax without deployment
access or third-party dependencies. Exercise changed scripts in temporary folders.
