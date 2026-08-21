# claude-skills

Internal Claude Code skills for the PopKult Go microservices workflow.
One installable plugin (`.claude-plugin/plugin.json`), one directory per
skill under `skills/`.

## Skills

| Skill | What it does |
|---|---|
| [`init-service`](skills/init-service/SKILL.md) | Scaffolds a brand-new service from `github.com/PopKult/service-template`, registers it in `prod-setup` and `local-setup`, and interviews the user to write a business-requirements doc into the new service's README. |
| [`add-feature`](skills/add-feature/SKILL.md) | Adds new functionality to an existing service: reads its standards doc + README, interviews until the request is clear, plans it as small gated phases (≤6 files/≤150 lines each), implements them one at a time on a feature branch, and touches `schema`/`prod-setup`/`local-setup` when needed. |

## Installing

Add this repo as a plugin so `init-service` (and anything added here
later) is available regardless of which repo you're working in:

```
/plugin marketplace add PopKult/claude-skills
/plugin install popkult-skills
```

Or, for local development on the skill itself, point Claude Code at a
local checkout of this repo via your plugin settings instead of
installing from the marketplace.

## Adding a new skill

Follow the format in `skills/init-service/` — a `SKILL.md` with YAML
frontmatter (`name`, `description`) plus imperative markdown
instructions, and a `scripts/` subdirectory for anything genuinely
repeated and mechanical (not for logic that needs judgment — that stays
in the SKILL.md instructions themselves). See the description field
guidance in `skills/init-service/SKILL.md`'s frontmatter for how
triggering works: be specific about *when* to use the skill, not just
what it does.
