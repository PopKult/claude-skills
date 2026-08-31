---
name: init-frontend
description: Scaffold a brand-new PopKult admin frontend for an existing Go service — a React + Vite + TypeScript + Apollo Client single-page app that talks to that service's GraphQL surface and gives an operator list/detail/CRUD views over the abstractions the service owns. Lays down the full scaffold (stack is fixed, no template repo), vendors the service's schema from github.com/PopKult/schema for typed codegen, registers the board in prod-setup (nginx k8s manifests) and local-setup (docker-compose), interviews the user for which abstractions get views and what each shows, then implements those views itself using add-feature's gated, phase-by-phase discipline. Use this whenever the user wants to create, scaffold, or bootstrap an admin board / dashboard / frontend / UI for an existing PopKult service, or says things like "juicer needs an admin frontend" or "build a dashboard for <service>" — even if they don't name this skill. The target frontend repo (PopKult/<service>-frontend) must already exist on GitHub. Do NOT use this for a brand-new backend service (that's init-service), for adding features to an already-built frontend (that's add-feature targeted at the frontend repo), or for anything server-side.
---

# init-frontend

Turns "I want an admin board for `<service>`" into a scaffolded,
locally-runnable React frontend with its real views implemented — the
multi-repo dance (frontend repo + `prod-setup` entry + `local-setup`
entry) done once, correctly, plus the GraphQL-schema wiring that a
generated admin board lives or dies on.

There is **no** `frontend-template` repo (unlike `service-template`).
The stack is fixed instead, and `scripts/scaffold-frontend.sh` lays it
down from scratch:

- **React + Vite + TypeScript** SPA.
- **Apollo Client** for GraphQL (cache, devtools, `useQuery`/`useMutation`).
- **GraphQL Code Generator**, client preset — typed operations generated
  from the schema.
- **Vendored schema.** The service's `graphql/<service>.graphqls` from
  `github.com/PopKult/schema` is copied into the frontend repo at
  `schema/<service>.graphqls`. Codegen and CI read that copy — they
  never need the private schema repo checked out. `npm run schema:sync`
  refreshes it.
- **Prod = static build behind nginx**, one image across all envs: the
  GraphQL endpoint is rendered into `config.js` at container start from
  `$GRAPHQL_ENDPOINT`, not baked in at build time.

Read `github.com/PopKult/service-template`'s
`docs/microservice-standards.md` §2.3 (GraphQL) before starting if you
haven't — the board is a GraphQL client and §2.3's additive-only rule
and topology question both bear on it.

This skill has two halves, same split as `init-service`. The first
(Phases 0–6) produces a scaffolded, requirements-documented board —
mechanical scaffold + registration + an interview written up as a README
section, committed straight to `main` in each repo since none of it is
application logic yet. The second (Phase 7) takes what the interview
described and actually implements the views, on a feature branch, using
the exact same small-reviewable-phases discipline as `add-feature`.

Phases 2 references `scripts/scaffold-frontend.sh` — that path is
relative to **this SKILL.md's own directory**, not the user's shell cwd.
Resolve its absolute path first (it's at `scripts/scaffold-frontend.sh`
next to this file) and invoke it by that absolute path.

## Phase 0 — locate the workspace

You need local sibling checkouts of `schema`, `prod-setup`,
`local-setup`, and the backend service's own repo (to read its README
and confirm its GraphQL topology). Check both the current directory and
one level up — you might be invoked from the workspace root, from inside
the backend service repo, or from inside the freshly-cloned empty
frontend repo:

```bash
ls schema prod-setup local-setup 2>/dev/null
ls ../schema ../prod-setup ../local-setup 2>/dev/null
```

Confirm each is the real repo (not a same-named coincidence) by checking
its `origin` remote points at `github.com/PopKult/*`. If you can't find
all of `schema` / `prod-setup` / `local-setup`, ask the user for the
PopKult workspace root rather than guessing — the same directory-name
collision that has bitten this system before (see
`local-setup/docker-compose.yml`'s comment on its explicit Compose
`name:`) applies here.

`schema` **does** need to be a local checkout for this skill — the
scaffold vendors a file out of it.

## Phase 1 — identify the service and the frontend repo

1. **Backend service name** `<service>`, lowercase kebab-case
   (`^[a-z][a-z0-9]*(-[a-z0-9]+)*$`), e.g. `juicer`. Ask if not already
   unambiguous from the conversation.
2. **The service must have a client-facing GraphQL surface.** Confirm
   `schema/graphql/<service>.graphqls` exists and check the service's
   README / standards-doc copy for its GraphQL topology decision (§2.3:
   single BFF, federated subgraph, or "not needed yet"). If the service
   has no GraphQL surface — no `.graphqls` file, topology "not needed
   yet" — **stop**: there's nothing for an admin board to talk to. Tell
   the user the service needs a GraphQL entrypoint first (that's an
   `add-feature` run against the service).
3. **The frontend repo must already exist.** `gh repo view
   PopKult/<service>-frontend` must succeed (created empty, same as
   every other PopKult repo). If it doesn't, stop and tell the user to
   create it first (`gh repo create PopKult/<service>-frontend --private`).
   Don't create it yourself. Note the casing `gh repo view` reports.
4. **Resolve the target directory** — same logic as `init-service`
   Phase 1:
   - Check `<workspace>/<service>-frontend` and whether the directory
     you were invoked from is already this repo (its `origin` matches).
   - **Doesn't exist anywhere:** fresh scaffold, target is
     `<workspace>/<service>-frontend`.
   - **Exists, is a git repo, `origin` resolves to
     `github.com/PopKult/<service>-frontend` case-insensitively, and has
     no frontend code** (no `package.json`, no `src/`): already-cloned
     empty repo — use it as-is, merge path.
   - **Exists but `origin` doesn't match, or already has frontend
     code:** stop and ask the user.
   - If the on-disk / GitHub repo name differs in casing from
     `<service>-frontend`, keep the directory and repo as their existing
     name but use lowercase `<service>-frontend` everywhere internal
     (package name, image name, `prod-setup`/`local-setup` entries). Say
     this to the user once.

## Phase 2 — scaffold the frontend repo

Let `<target_dir>` be whatever Phase 1 resolved:

```bash
scripts/scaffold-frontend.sh <target_dir> <service>
```

The script handles both the fresh and merge cases (see its header). It
vendors `../schema/graphql/<service>.graphqls` into
`<target_dir>/schema/<service>.graphqls` — if it warns that it couldn't
find the schema, stop and fix the workspace layout; a placeholder schema
makes every later phase meaningless.

**Bump the dependency versions** in the generated `package.json` to
current stable if the floors in the script have aged — same judgment
call `service-template`'s own deps get. Do this before `npm install`.

If `<target_dir>` didn't exist before (fresh path):

```bash
cd <target_dir>
git init -q
git branch -m main
git remote add origin "https://github.com/PopKult/<service>-frontend.git"
```

If it already existed with a `.git` (merge path), skip those — `origin`
was confirmed in Phase 1.

Then verify it's a working scaffold before going further:

```bash
cd <target_dir>
npm install
npm run codegen
npm run lint
npm run typecheck
npm run build
```

All must pass. If anything fails, fix it before Phase 3 — a broken
scaffold makes every later step suspect. (`npm run codegen` against the
real vendored schema is also your first real check that the schema file
is valid SDL.)

Commit the scaffold on its own:

```bash
git add -A && git commit -m "Scaffold <service>-frontend admin board"
```

## Phase 3 — GraphQL connection + auth (must ask, don't guess)

Two things the scaffold deliberately leaves open — ask the user
directly:

- **How does the board reach GraphQL?** Directly at the service's own
  GraphQL endpoint (single BFF — most common), or via the federation
  gateway? This sets the endpoint URL for local dev
  (`http://localhost:<service-http-port>/query` vs the gateway's) and
  for prod (the service's ingress vs the gateway's).
- **What auth does that edge expect?** §2.3 says external clients
  authenticate via JWT validated at the GraphQL edge — but an internal
  admin board might sit behind VPN/ingress auth with none of its own, or
  use a static token. Find out: no auth, static bearer token, JWT login
  flow, or something else. This drives the Apollo auth-link wiring and
  whether the board needs a login screen.

Record both answers — they go into the requirements doc in Phase 4 and
get implemented in Phase 7. Don't wire auth code yet.

## Phase 4 — abstractions + views interview

A real interview, not a form — keep asking follow-ups until you could
describe the board back to someone who hasn't seen the conversation.
Ground it in two things you read first: `schema/<service>.graphqls` (the
types, queries, and mutations that actually exist) and the service's
README business-requirements section (what the abstractions *mean*).
Cover roughly:

- **Which abstractions get views.** Walk the schema's top-level object
  types and the service README's domain entities together. Which ones
  does an operator need to see and act on? (Some types are nested
  detail, not top-level views.)
- **Per abstraction:** the list view (which columns; which filters /
  search — many `list*` / `search*` queries take `limit`/`offset` and
  status filters); the detail view (which fields, including nested
  ones); which mutations are surfaced as actions (create, edit, delete,
  approve, regenerate, run-a-stage, …) and which fields are
  editable vs read-only.
- **Workflow screens.** Some services have a staged pipeline (e.g.
  Juicer's `HarvestingSession` → run/approve each stage, poll a
  background job's status). Does this board need a bespoke workflow
  screen rather than plain list/detail?
- **The abstractions overview.** The landing page: one card per
  abstraction with a one-line description (from the README) and a link
  to its view. Confirm what belongs there.
- **Auth / login UX** from Phase 3.

When it's genuinely clear, write the synthesis into
`<target_dir>/README.md`:

- Replace the placeholder blockquote in the scaffold's requirements
  section with the real thing: connection topology + auth (Phase 3),
  the abstraction inventory, per-abstraction views and actions, any
  workflow screens, the overview page.
- Leave the rest of the README (Stack, GraphQL schema, Local
  development, Runtime config, Deployment) as-is — still accurate.

Commit:

```bash
git add -A && git commit -m "Document <service>-frontend's admin board requirements"
```

## Phase 5 — register in prod-setup

There's no `service-template` equivalent to copy for a frontend — write
`prod-setup/services/<service>-frontend/deployment.yaml` by hand,
following the shape of a service `deployment.yaml` but for a static
nginx app:

- **Deployment** — image `docker.io/popkult/<service>-frontend:latest`,
  one container, `containerPort: 80`. Readiness and liveness are both
  plain HTTP `GET /` on port 80 (there's no gRPC health service here —
  it's a static file server). `envFrom` the ConfigMap below. Modest
  resources (`64Mi`/`128Mi` is plenty for nginx).
- **Service** — `port: 80`, `targetPort: 80`.
- **ConfigMap** `<service>-frontend-config` — `GRAPHQL_ENDPOINT` set to
  the endpoint Phase 3 settled on (the service's in-cluster address or
  the federation gateway's). This is the var the container's
  `40-render-config.sh` reads at start.
- **Ingress** — the admin hostname. Follow whatever ingress pattern
  `prod-setup` already uses for client-facing surfaces; if there's no
  precedent yet, add the Ingress resource and flag to the user that the
  hostname / TLS / ingress-class values are placeholders they need to
  confirm.

No `migrate-job.yaml`, no `outbox-relay-deployment.yaml` — a frontend
has neither.

```bash
cd <workspace>/prod-setup
git add -A && git commit -m "Add <service>-frontend k8s manifests"
```

## Phase 6 — register in local-setup

Edit `local-setup/docker-compose.yml` directly:

1. Add one `<service>-frontend` block: `build.context:
   ../<service>-frontend` (use the target directory's actual on-disk
   name if casing differs), `dockerfile:
   deployments/docker/Dockerfile`. No `secrets: [netrc]` — the frontend
   build has no private Go modules. `depends_on` the backend service.
2. `environment: GRAPHQL_ENDPOINT: http://localhost:<published-http-port>/query`
   — **a host-reachable URL, not the compose-internal hostname.** The
   board is static files served by nginx; the GraphQL calls run in the
   operator's *browser*, which resolves `localhost`, not `juicer`. Take
   `<published-http-port>` from the backend service's own compose block
   (its published `HTTP_PORT` mapping, e.g. Juicer publishes `8081:8081`
   → `http://localhost:8081/query`). This is the single most common way
   to get this block wrong.
3. Pick a new host port: scan every `ports:` entry in the file, take the
   next free one above the current max (frontends have no established
   range — `8090:80` upward is fine), publish container `80`.
4. No `postgres-init/` file — the board has no database.
5. Validate: `docker compose config` from inside `local-setup/` must
   succeed.

```bash
git add -A && git commit -m "Add <service>-frontend to local dev stack"
```

Report the scaffold's status — what changed in the frontend repo,
`prod-setup`, and `local-setup` — before Phase 7. Nothing has been
pushed; that stays true through Phase 7.

## Phase 7 — implement the admin board

Phase 4's interview and the README section it produced are exactly the
input `add-feature` expects. Invoke it now (`Skill` tool,
`popkult-skills:add-feature`) to implement the board — but its first two
phases are already done, don't repeat them:

- Its **Phase 0** (locate context, read standards + README) is
  satisfied — you're in the frontend repo you just scaffolded and wrote
  the README for. One adaptation: `add-feature` assumes a Go service
  (`go build`, `golangci-lint`). Here the per-phase verification gate is
  **`npm run codegen && npm run lint && npm run typecheck && npm run
  build`**, all clean, at the end of every phase.
- Its **Phase 1** (open-ended interview) is satisfied by Phase 4 above.

Start from its **Phase 2** and follow through to its Phase 8. Plan the
board into small reviewable phases (≤6 files / ≤150 changed lines each,
repo buildable at every phase), e.g.:

- Apollo auth link + login screen (from Phase 3), if any.
- Shared UI: layout/nav, a reusable table, loading/error states.
- The abstractions overview page.
- One abstraction at a time: its GraphQL operations (`.graphql`
  documents → `npm run codegen`), list view, detail view, then its
  mutation actions — often two or three phases per abstraction.
- Any bespoke workflow screen.

Present the full phase breakdown to the user before implementing.
Branch (`add-admin-board` or similar), implement each phase gated on
explicit go-ahead, and report without pushing.

**Backend implications — flag, don't silently absorb:**

- **Missing data.** If the interview revealed the board needs a field,
  query, or filter that isn't in `<service>.graphqls`, that's a `schema`
  change (additive-only, §2.3) *and* a resolver change in the service.
  Out of scope here: finish the board against what the schema has, and
  tell the user which `add-feature` run against the service (plus
  `schema` PR) would add the rest. Don't invent client-side workarounds
  for missing server data.
- **Admin actions.** A board that drives mutations means the service now
  has admin actions — `docs/microservice-standards.md` §1.4 wants those
  audit-logged (`internal/audit/`). If the service doesn't have that
  yet, flag it as a follow-up `add-feature` on the service.

## Reference

- `scripts/scaffold-frontend.sh <target_dir> <service>` — the one
  bundled script. Lays down the full React/Vite/Apollo/codegen scaffold,
  vendors the service's GraphQL schema from `../schema`, writes the
  nginx Dockerfile + CI + README. Fresh-copy if `<target_dir>` doesn't
  exist; merge-in if it's an existing empty git repo (leaves `.git` /
  `.idea`); refuses if it already has frontend code. Does no
  `npm install` / git / commit — Phase 2 does those.
