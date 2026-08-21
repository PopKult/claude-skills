---
name: add-feature
description: Add new functionality to an EXISTING PopKult Go microservice — reads the standards doc and the service's own documented business logic first, interviews the user until the request is genuinely clear, plans the change as small reviewable phases (max 6 files / 150 changed lines each), implements them one at a time with a stop-and-review gate after every phase, and touches schema/prod-setup/local-setup too when the feature needs it. Use this whenever the user wants to add, implement, build, or extend a feature/use case/endpoint/event in a service that already exists — phrases like "add X to order-service", "implement Y", "order-service needs to support Z" — even if they don't name this skill explicitly. Do NOT use this for creating a brand-new service (that's init-service) or for pure bug fixes with no new functionality.
---

# add-feature

Turns "add `<functionality>` to `<service>`" into a small set of
reviewable, individually-verified commits on a feature branch — grounded
in what the standards doc requires and what the service's README says it
actually does, not a guess at either.

**Read the target service's own `docs/microservice-standards.md`
before starting** (Phase 0 below) if you haven't already this session —
you'll need §1.1 (use case naming), §2.1/§2.3 (schema/GraphQL
additive-only + confirm-with-user rules), §1.3 (outbox pattern), and §11
(PII/redaction) as this skill runs.

This skill never touches `main` directly and never pushes anything —
everything happens on a local feature branch, reported at the end, left
for the user to push when they're ready. It also never chains multiple
implementation phases without stopping: **every phase gets its own
review gate**, even if the user already approved the overall phase
breakdown — approving the plan is not the same as approving the diff.

## Phase 0 — locate context

The target service is the repo you're invoked in — the one whose
`go.mod` module is `github.com/PopKult/<name>`. If that's not clear
(invoked somewhere else entirely), ask which service.

Read that service's own `docs/microservice-standards.md` — the copy
`init-service` put there when the service was created. That copy is
what this service is actually built against; treat it as authoritative
for this run, don't go looking for some other "more canonical" copy
elsewhere.

Read the target service's `README.md`, specifically the business
requirements section `init-service` wrote: purpose, domain entities, use
cases, integrations, GraphQL topology decision, sensitive data. This is
your baseline for Phase 2.

Locate the PopKult workspace root (sibling checkouts) only if/when
Phase 3 determines the feature needs `schema`, `prod-setup`, or
`local-setup` changes — check `../schema`, `../prod-setup`,
`../local-setup` relative to the service repo, confirming each
candidate's `origin` remote is actually `github.com/PopKult/*` before
trusting it (a same-named unrelated directory has bitten this system
before — verify, don't assume).

## Phase 1 — clarify what to implement

Open-ended interview. Figure out what the user actually wants: a new use
case, a new field on an existing entity, a new gRPC/GraphQL surface, a
new Kafka event produced or consumed, something else. Keep asking
follow-ups until you genuinely understand it — a fixed checklist you run
through once is not the bar here; the bar is that you could correctly
describe the feature back to someone who hasn't seen this conversation.

## Phase 2 — check against README/standards, update if needed

- Does the request fit the domain already documented in the README (its
  entities, use cases, integrations)? If it's a natural extension,
  proceed. If it conflicts with what's documented, or the README doesn't
  cover this territory at all, say so and clarify with the user rather
  than silently reconciling it yourself.
- Check whether the feature touches any standards-doc point that
  requires asking rather than deciding: §2.3 (GraphQL topology, if this
  is the service's first client-facing GraphQL surface and it wasn't
  decided when the service was created), §11.2/§11.3 (any new PII or
  sensitive field needs field-level encryption and `secure.String`
  redaction — flag it now, don't let it surface later as a security
  review finding).
- Once settled, update the README's business-requirements section to
  describe the new functionality — keep the doc and the code from
  diverging, same principle `init-service` established when it first
  wrote that section.

## Phase 3 — plan the phases

Break the implementation into phases. Per phase:
- **≤6 files changed, ≤150 changed lines.** A guideline for *how to
  slice* the work, not a license to leave the tree broken between
  phases — a phase that would require breaking a migration from its
  handler, or an interface from its only implementation, to hit the cap
  is sliced wrong; find a different cut, don't ship a broken phase.
- **Must leave the repo buildable and tests passing** on its own —
  `go build ./...` and `go test ./...` clean at the end of every single
  phase, not just at the end of the whole feature.
- **A short description of what it does and why**, not just a file
  list — the point is the user can review a phase without having read
  the whole plan again.

While planning, identify — don't discover mid-implementation — whether
this feature needs:
- **`schema` changes**: a new/changed proto RPC, message, or GraphQL
  field. Additive-only (§2.1/§2.3) — never edit or remove a released
  field/RPC in place.
- **`prod-setup` changes**: a new env var in the service's `ConfigMap`,
  a new k8s resource.
- **`local-setup` changes**: a new env var, a new Kafka topic, etc. in
  the compose file.
- **Another service adapting to a new/changed contract** this service
  will now expose (a new gRPC RPC another service will call, a new
  Kafka event another service needs to consume). Note which service and
  why — this drives Phase 7, after the current service is fully done.

Present the complete phase breakdown — including any
schema/prod-setup/local-setup phases — to the user before implementing
anything.

## Phase 4 — branch

Create a feature branch in the target service repo, named
`add-<feature-slug>`. If Phase 3 identified `schema`/`prod-setup`/`local-setup`
changes, create the same-named branch in each of those repos too, for
traceability across repos. Never commit to `main` in any of them.

## Phase 5 — implement phases, gated

For each planned phase, in order:
1. Implement the files.
2. Verify: `go build ./...`, `go vet ./...`, `go test ./...`, and the
   linter (`golangci-lint run ./...`) — all clean before the phase
   counts as done. A phase that doesn't pass isn't finished; fix it
   before moving on, don't move on and fix it "in the next phase."
3. Commit on the feature branch, message naming the phase
   (e.g. `git commit -m "add-feature: phase 2 — CreateWidget use case"`).
4. Show the diff and the phase's description to the user.
5. **Stop.** Wait for explicit go-ahead before starting the next phase —
   every phase, not just the risky-looking ones.

## Phase 6 — schema / prod-setup / local-setup

If Phase 3 identified changes here, implement them on their own feature
branches, with the same gated-phase discipline as Phase 5 (verify, show
diff, wait). One thing to call out to the user explicitly: a `schema`
change isn't actually consumable by the service until it's merged and
tagged (the service would `go get github.com/PopKult/schema@vX.Y.Z` to
pick it up). For phases in *this* service that need the new schema
content before that's landed, either sequence them to come after
schema's PR is merged and tagged, or use a local `go.work` override for
interim development — the same technique this whole system was
bootstrapped with when service-template first depended on unpublished
go-common/schema. If you use the override, say plainly that it's
temporary scaffolding for local development and must not ship — the
service's `go.mod` still needs a real tagged version before this is
done.

## Phase 7 — cross-service loop

If Phase 3 flagged that another service must adapt to a new/changed
contract: once the current service's phases are all done, tell the user
which service(s) need updating and specifically why (e.g. "order-service
now calls the new `ReserveInventory` RPC on inventory-service" / "the
new `order.created.v2` event needs a consumer added in
shipping-service"). With the user's confirmation, run this same skill
again targeted at that service. Skip Phase 1's open-ended interview
there — the requirement is already known ("consume `order.created.v2`",
"call `ReserveInventory`") — and start from Phase 2: check it against
*that* service's own README and standards-doc copy, then plan phases for
it the same way.

## Phase 8 — report, don't push

Summarize every branch and commit created, across every repo touched
(the service, and any of `schema`/`prod-setup`/`local-setup`). State
plainly that nothing has been pushed and no PR has been opened. Wait for
the user to explicitly ask before running `git push` anywhere — don't
lead with "should I push?" either, just report status and let them
decide when.
