---
name: init-service
description: Scaffold a brand-new PopKult Go microservice from service-template, end to end — copies and renames the template into a new service repo (whether that repo needs creating fresh or already exists as an empty clone), registers it in prod-setup (k8s manifests) and local-setup (docker-compose), interviews the user for the service's business requirements to write into its README, and then implements that initial business logic itself using add-feature's gated, phase-by-phase discipline. Use this whenever the user wants to create, scaffold, bootstrap, or init a new PopKult service or microservice, mentions "service-template", or says things like "let's start a new service called X" or "I need a service for Y" — even if they don't name this skill explicitly. Do NOT use it for changes to an existing, already-implemented service; that's add-feature.
---

# init-service

Turns "I want a new PopKult service called `<name>`" into a fully
scaffolded, locally-runnable service with its initial business logic
implemented — the multi-repo dance (service repo + `prod-setup` entry +
`local-setup` entry) done once, correctly, instead of re-derived by hand
every time.

Read `github.com/PopKult/service-template`'s
`docs/microservice-standards.md` before starting if you haven't already
— it's the binding spec this whole skill exists to apply. Everything
below assumes you've read it, especially §1 (layout), §2.3 (GraphQL
topology — must ask), and §1.1 (use case naming).

This skill has two halves. The first (Phases 0–6) produces a
scaffolded, requirements-documented service — mechanical rename +
registration + an interview written up as a README section, all
committed straight to `main` in each repo since none of it is business
logic yet, so there's nothing there worth a review gate. The second
(Phase 7) takes what that interview described and actually implements
it, on a feature branch, using the exact same small-reviewable-phases
discipline as the `add-feature` skill — because once real business logic
is being written, it deserves that care, unlike the mechanical first
half.

Phases 2 and 5 below call `scripts/copy-and-rename.sh` — that path is
relative to **this SKILL.md's own directory**, not wherever the user's
shell happens to be. Resolve its absolute path first (it lives at
`scripts/copy-and-rename.sh` next to this file) and invoke it by that
absolute path, since the working directory for the actual copy/rename
commands is the PopKult workspace, not the skill bundle.

## Phase 0 — locate the workspace

You need local checkouts of `service-template`, `prod-setup`, and
`local-setup` as sibling directories (this is the layout the whole
PopKult multi-repo system assumes — see each repo's own README). Check
both relative to the current directory and one level up — you might be
invoked from the workspace root, from inside one of these three repos,
or from inside the new service's own repo if the user already `git
clone`d its (empty) GitHub repo before asking you to scaffold it:

```bash
ls service-template prod-setup local-setup 2>/dev/null
ls ../service-template ../prod-setup ../local-setup 2>/dev/null
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

## Phase 1 — get and validate the service name, find the target directory

Ask the user for the new service's name, kebab-case (e.g.
`order-service`). Validate before doing anything else:

1. Lowercase kebab-case (`^[a-z][a-z0-9]*(-[a-z0-9]+)*$`).
2. `gh repo view PopKult/<name>` succeeds. **The GitHub repo must
   already exist** (created empty, same as every other PopKult repo) —
   if it doesn't, stop and tell the user to create it first
   (`gh repo create PopKult/<name> --private` or via the GitHub UI).
   Don't create it yourself. GitHub repo names are case-insensitive, so
   this also catches the repo already existing under a differently-cased
   spelling (e.g. `Juicer` for a service you'd otherwise call
   `juicer`) — note whatever casing `gh repo view` reports, you'll need
   it next.
3. Work out the target directory and whether it already exists:
   - Check `<workspace>/<name>` (and its differently-cased form from
     step 2) and, separately, whether the directory you were invoked
     from already looks like this repo (its `origin` matches).
   - **Doesn't exist anywhere:** proceed with Phase 2's fresh-copy path,
     target is `<workspace>/<name>`.
   - **Exists, is a git repo, `origin` resolves to
     `github.com/PopKult/<name>` case-insensitively, and has no service
     code in it yet** (no `go.mod`, no `internal/` — just whatever `gh
     repo create` or the user's own setup left there, e.g. a starter
     `.gitignore`/`.idea`): this is an already-cloned empty repo. Use it
     as the target directory as-is — don't rename or move it — and
     proceed with Phase 2's merge path.
   - **Exists but `origin` doesn't match, or it already contains service
     code:** stop and ask the user; don't guess your way past a real
     conflict.
   - If the directory/repo's actual name differs in casing from the
     lowercase kebab-case `<name>` (e.g. dir is `Juicer`, service name
     is `juicer`), keep the directory and GitHub repo as their existing
     name, but use the lowercase kebab-case form everywhere internal —
     Go module path, `SERVICE_NAME`, the `prod-setup`/`local-setup`
     entries, the DB name. Say this out loud to the user once so it's an
     acknowledged decision, not a silent inconsistency.

## Phase 2 — copy + rename the service repo

Let `<target_dir>` be whatever Phase 1 resolved (either the pre-existing
directory, or `<workspace>/<name>`, not yet created):

```bash
scripts/copy-and-rename.sh <workspace>/service-template <target_dir> service-template <name>
```

The script handles both cases on its own: if `<target_dir>` doesn't
exist, it does a plain fresh copy. If `<target_dir>` already exists as a
git repo, it **merges** the template's contents into it instead —
overwriting any same-named file already there (including `.gitignore`),
except it leaves `<target_dir>/.git` (the real history/remote) and
`<target_dir>/.idea` (pre-existing local IDE config, if any) untouched.
See the script's own header comment for exact behavior.

If `<target_dir>` didn't exist before this command (fresh path):

```bash
cd <target_dir>
git init -q
git branch -m main
git remote add origin "https://github.com/PopKult/<name>.git"
```

If `<target_dir>` already existed with a `.git` (merge path), skip those
three lines — it's already initialized and `origin` was already
confirmed in Phase 1.

Then **verify it's still a working service** before going any further —
don't take it on faith that the rename was clean:

```bash
cd <target_dir>
go build ./...
go vet ./...
go test ./...
```

If anything fails here, stop and fix it before Phase 3 — a broken
scaffold makes every later step suspect. (It shouldn't fail: the rename
is a pure string substitution and `service-template` itself is verified
in CI, but confirm anyway — same discipline used when this template was
first built.)

Commit the scaffold on its own, before anything else lands on top of it:

```bash
git add -A && git commit -m "Scaffold service from service-template"
```

## Phase 3 — GraphQL topology (must ask, don't guess)

`docs/microservice-standards.md` §2.3 flags GraphQL gateway topology as
genuinely undecided per-service — ask the user directly:

- Single BFF (this service resolves GraphQL fields itself, calling other
  services over gRPC)?
- Federated subgraph (composed by a separate federation gateway)?
- Not needed yet (no client-facing GraphQL surface for this service)?

Record the answer — you'll fold it into the requirements doc in Phase 4.
Don't wire any code in `internal/entrypoint/graphql/` based on the
answer yet; that happens in Phase 7, alongside everything else Phase 4
describes.

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
  the doc is directly actionable in Phase 7.
- **Outbound calls**: does it need to call other services synchronously
  (gRPC), or a non-PopKult external dependency (plain HTTP, an embedded
  binary, etc.)? Which ones, for what?
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
   `service-template` to `<name>` (including `build.context: ../<name>`
   — use the target directory's actual on-disk name here, which per
   Phase 1 may differ in casing from `<name>`).
2. Pick new host ports: scan the file's existing `ports:` entries, find
   the highest published port already in use *anywhere* in the file
   (not just within one service's block — shared infra like Kafka can
   occupy a port that would otherwise look "next" in one of the three
   per-service ranges), and use the next free one in each of the three
   ranges (gRPC ~50051, service metrics ~9090, relay metrics ~9091) —
   same convention documented in `local-setup/README.md`'s "Adding a new
   service" section.
3. Add `local-setup/postgres-init/<NNN>-<name>.sql` containing
   `CREATE DATABASE "<name>";`, numbered after the highest existing file.
4. Validate before committing: `docker compose config` (from inside
   `local-setup/`) must succeed.

```bash
git add -A && git commit -m "Add <name> to local dev stack"
```

At this point, report the scaffold's status — what changed in the
service repo, `prod-setup`, and `local-setup` — before moving into
Phase 7. Nothing has been pushed anywhere yet; that stays true through
Phase 7 too.

## Phase 7 — implement the initial business logic

Phase 4's interview, and the README section it produced, are exactly the
input the `add-feature` skill expects as its baseline (see that skill's
Phase 0). Invoke it now (`Skill` tool, `popkult-skills:add-feature`) to
implement what Phase 4 described — but its first two phases are already
done, so don't repeat them:

- Its **Phase 0** (locate context: confirm the target repo, read the
  standards doc + README) is already satisfied — you're sitting in the
  service repo you just scaffolded, and you just wrote the README
  section it would read.
- Its **Phase 1** (open-ended interview) is already satisfied by Phase 4
  above — don't re-interview the user for the same information.

Start from its **Phase 2** (check the request against the
README/standards — trivially true here, you just wrote that section
from this exact conversation) and follow it through to its Phase 8
(report, don't push): plan the business logic into small reviewable
phases, present the breakdown to the user, branch, implement each phase
gated on explicit go-ahead, touch `schema`/`prod-setup`/`local-setup` if
the plan needs it, and report without pushing.

Treat this like any other `add-feature` run — real business logic on a
feature branch, never batched past a review gate, never pushed — not
like the mechanical, straight-to-`main` rename from Phases 2–6 above.

## Reference

- `scripts/copy-and-rename.sh <src> <dest> <old> <new>` — the one
  bundled script. Copies a directory and replaces every literal
  occurrence of `old` with `new` in every file under the copy. If
  `dest` doesn't exist, it's a plain fresh copy (`.git` excluded). If
  `dest` already exists as a git repo, it merges `src`'s contents into
  it instead, preserving `dest`'s own `.git` and `.idea`. Used in
  Phase 2 and Phase 5.
