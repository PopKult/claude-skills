---
name: init-service
description: Scaffold a brand-new PopKult Go microservice from service-template, end to end — copies and renames the template into a new service repo, registers it in prod-setup (k8s manifests) and local-setup (docker-compose), and interviews the user for the service's business requirements to write into its README. Use this whenever the user wants to create, scaffold, bootstrap, or init a new PopKult service or microservice, mentions "service-template", or says things like "let's start a new service called X" or "I need a service for Y" — even if they don't name this skill explicitly. Do NOT use it for changes to an existing service; it only creates new ones.
---

# init-service

Turns "I want a new PopKult service called `<name>`" into a fully
scaffolded, locally-runnable, requirements-documented service — the
multi-repo dance (service repo + `prod-setup` entry + `local-setup`
entry) done once, correctly, instead of re-derived by hand every time.

Read `github.com/PopKult/service-template`'s
`docs/microservice-standards.md` before starting if you haven't already
— it's the binding spec this whole skill exists to apply. Everything
below assumes you've read it, especially §1 (layout), §2.3 (GraphQL
topology — must ask), and §1.1 (use case naming).

This skill **produces a requirements document, not business-logic
code**. Beyond the renamed template, it writes zero domain code — the
interview in Phase 4 exists to capture what a *later* session will
implement against `internal/domain`, `internal/usecase/*`, etc. Don't
let the interview drift into "let me also scaffold the use case for
you" — that's out of scope here, on purpose, so the template stays a
clean, verified starting point rather than an agent's first guess at the
business logic.

Phases 2 and 5 below call `scripts/copy-and-rename.sh` — that path is
relative to **this SKILL.md's own directory**, not wherever the user's
shell happens to be. Resolve its absolute path first (it lives at
`scripts/copy-and-rename.sh` next to this file) and invoke it by that
absolute path, since the working directory for the actual copy/rename
commands is the PopKult workspace, not the skill bundle.

## Phase 0 — locate the workspace

You need local checkouts of `service-template`, `prod-setup`, and
`local-setup` as sibling directories (this is the layout the whole
PopKult multi-repo system assumes — see each repo's own README). Check:

```bash
ls service-template prod-setup local-setup 2>/dev/null   # from the current directory
ls ../service-template ../prod-setup ../local-setup 2>/dev/null   # if you're invoked from inside one of them
```

If found, confirm each is actually the right repo (not a same-named
coincidence) by checking its `origin` remote points at
`github.com/PopKult/*`. If you can't find all three, ask the user for
the PopKult workspace root path rather than guessing — this is exactly
the kind of directory-name-collision risk that has bitten this system
before (an unrelated `local-setup` elsewhere caused real damage; see
`local-setup/docker-compose.yml`'s comment on why it sets an explicit
Compose `name:`). Don't proceed against a directory you haven't verified.

`go-common` and `schema` do **not** need to be local checkouts — the new
service depends on them via `go get` over the network, not by local
path.

## Phase 1 — get and validate the service name

Ask the user for the new service's name, kebab-case (e.g.
`order-service`). Validate before doing anything else:

1. Lowercase kebab-case (`^[a-z][a-z0-9]*(-[a-z0-9]+)*$`).
2. No existing directory of that name already in the workspace.
3. `gh repo view PopKult/<name>` succeeds. **The GitHub repo must
   already exist** (created empty, same as every other PopKult repo) —
   if it doesn't, stop and tell the user to create it first
   (`gh repo create PopKult/<name> --private` or via the GitHub UI).
   Don't create it yourself.

## Phase 2 — copy + rename the service repo

```bash
scripts/copy-and-rename.sh <workspace>/service-template <workspace>/<name> service-template <name>
cd <workspace>/<name>
git init -q
git branch -m main
git remote add origin "https://github.com/PopKult/<name>.git"
```

Then **verify it's still a working service** before going any further —
don't take it on faith that the rename was clean:

```bash
go build ./...
go vet ./...
go test ./...
```

If anything fails here, stop and fix it before Phase 3 — a broken
scaffold makes every later step suspect. (It shouldn't fail: the rename
is a pure string substitution and `service-template` itself is verified
in CI, but confirm anyway — same discipline used when this template was
first built.)

## Phase 3 — GraphQL topology (must ask, don't guess)

`docs/microservice-standards.md` §2.3 flags GraphQL gateway topology as
genuinely undecided per-service — ask the user directly:

- Single BFF (this service resolves GraphQL fields itself, calling other
  services over gRPC)?
- Federated subgraph (composed by a separate federation gateway)?
- Not needed yet (no client-facing GraphQL surface for this service)?

Record the answer — you'll fold it into the requirements doc in Phase 4.
Don't wire any code in `internal/entrypoint/graphql/` based on the
answer; recording the decision is the deliverable here, not an
implementation.

## Phase 4 — business-logic interview

This is a real interview, not a form — keep asking follow-ups until you
genuinely understand the service, not until you've asked a fixed list of
questions once. Use your judgment about what's already clear from what
the user has said versus what's still fuzzy. Ground covers roughly:

- **Purpose**: one or two sentences — what does this service own, why
  does it need to exist as its own service rather than living inside
  another one?
- **Domain entities**: the main things it owns data about.
- **Use cases**: the business operations it needs to support. Phrase
  each as a candidate `internal/usecase/<name>` per §1.1's naming
  convention (`CreateOrderUseCase`, not a grab-bag `OrderUseCase`) so
  the doc is directly actionable when someone implements it later.
- **Outbound gRPC calls**: does it need to call other services
  synchronously? Which ones, for what?
- **Kafka events**: does it publish anything via the outbox (§1.3)? Does
  it need to consume anything another service publishes?
- **Sensitive data**: any PII or secrets it will store — relevant to
  §11's field-level encryption (§11.2) and redaction (§11.3)
  requirements, so flag it now rather than discovering it later.

When it feels genuinely clear (not just "I asked six questions"), write
the synthesis into `<name>/README.md`:

- Add a new section right after the H1 title — before the inherited
  "What's actually implemented" reference table — covering purpose,
  domain entities, use cases, integrations, sensitive data, and the
  GraphQL topology decision from Phase 3.
- **Delete** the inherited "Turning this into a new service" section
  entirely — it only made sense while this was still the template.
- Leave the rest of the README (What's actually implemented, Local
  development, CI secrets, Private module auth) as-is — still accurate.

Commit this as its own commit, separate from the scaffold:

```bash
git add -A && git commit -m "Document <name>'s business requirements"
```

## Phase 5 — register in prod-setup

```bash
scripts/copy-and-rename.sh <workspace>/prod-setup/services/service-template <workspace>/prod-setup/services/<name> service-template <name>
cd <workspace>/prod-setup
git add -A && git commit -m "Add <name> k8s manifests"
```

## Phase 6 — register in local-setup

Edit `local-setup/docker-compose.yml` directly (no script for this one —
it's an in-place edit of an existing multi-service file, not a directory
copy):

1. Duplicate the `service-template` / `service-template-migrate` /
   `service-template-outbox-relay` blocks, renaming each occurrence of
   `service-template` to `<name>` (including `build.context: ../<name>`).
2. Pick new host ports: scan the file's existing `ports:` entries, find
   the highest published port in each of the three ranges already in use
   (gRPC ~50051, service metrics ~9090, relay metrics ~9091), and use the
   next free one — same convention documented in `local-setup/README.md`'s
   "Adding a new service" section.
3. Add `local-setup/postgres-init/<NNN>-<name>.sql` containing
   `CREATE DATABASE "<name>";`, numbered after the highest existing file.
4. Validate before committing: `docker compose config` (from inside
   `local-setup/`) must succeed.

```bash
git add -A && git commit -m "Add <name> to local dev stack"
```

## Phase 7 — report, don't push

Summarize what changed across all three repos — the new service repo
(scaffold + requirements README), the `prod-setup` entry, the
`local-setup` entry — and say plainly that nothing has been pushed yet.
Wait for the user to ask before running `git push` anywhere. Don't ask
"should I push?" as a leading question either — just report status and
let them decide when.

## Reference

- `scripts/copy-and-rename.sh <src> <dest> <old> <new>` — the one
  bundled script. Copies a directory and replaces every literal
  occurrence of `old` with `new` in every file under the copy (skips
  `.git`). Used in Phase 2 and Phase 5.
