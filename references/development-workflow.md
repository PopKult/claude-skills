# PopKult development workflow

Read this for init-service, init-frontend, add-feature and add-mobile-feature.

## Context and authorization

Read the target repository's AGENTS.md and relevant business/technical documents.
Use information already supplied in the conversation; ask only about missing
decisions that affect the result. Do not repeat a completed interview when
continuing another skill's workflow. If documentation conflicts with the request
or current implementation, explain the conflict and resolve the relevant part.

Before changing sibling repositories, locate the workspace and verify their
origin remotes belong to PopKult. Preserve existing directory/repository casing
(Juicer, Juicer-Adm, PopkultMobileapp); deployment names may differ. Do not infer
a frontend's repository name from its Kubernetes name.

## Branches and execution

Use a feature branch for every change, including scaffolding and documentation.
Inspect status first; preserve the user's uncommitted changes. Use an isolated
checkout when the current branch or working tree belongs to another task.
For related repository changes, use the same branch name where practical.

Describe the intended change and verification before implementing. Once the
scope is clear, complete it without mandatory pauses after each phase or commit.
Make coherent, reviewable commits; file/line counts are not hard limits and
must not force broken intermediate states. Pause for a material unresolved
product/architecture decision or when the user explicitly requests staged review.

Push and open PRs when the user requests them. Existing authorization applies
across the task; do not ask again for each repository. Otherwise report local
branches and checks. Do not merge a PR as part of opening it. A development
request does not authorize production promotion or other unrelated operations.

## Cross-repository contracts

- Read the service's own docs/microservice-standards.md. For a new service,
  use service-template's copy. Flag relevant drift rather than silently imposing
  every new template rule on an existing service.
- Keep protobuf/GraphQL changes additive in schema. Publish schema/go-common
  as real semver dependencies before shipping consuming service changes.
  A temporary go.work override is local scaffolding, not a release dependency.
- Migrations must work with both old and new binaries during canary and rollback:
  expand, backfill, switch reads, contract in a later release. Production abort
  never runs down migrations. Ship migrations inside the service image.
- Check prod-setup/local-setup for changed env vars, secrets, ports, topics and
  resources. Add producers/consumers consistently; Kafka auto-creation is disabled.
- Update business documentation with the implementation. Include changes in other
  services when required by the agreed feature; explain dependencies between PRs.
- Preserve transactional outbox delivery and idempotent consumers. Continue trace
  context through the outbox and Kafka headers. Log decisions/failures via slog
  context methods, with IDs/counts rather than payloads, tokens or practice text.

## Verification

Run checks appropriate to the changed behavior, plus repository-required checks.
For Go code: go build ./..., go vet ./..., go test ./..., golangci-lint run ./....
Run integration tests for changed SQL, storage or relay behavior with Docker.
For admin UI: npm run codegen, npm run lint, npm run typecheck, npm run build.
For mobile: relevant module tests and Android/iOS checks described by its docs
and CI. Documentation-only edits need link/content checks, not full app builds.
Fix failures introduced by the change; distinguish pre-existing/environment
failures and report any unverified behavior honestly.

End with changes, checks, remaining limitations and branches or PR links.
