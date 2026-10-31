---
name: init-service
description: Create a PopKult Go microservice from service-template, register it in prod-setup/local-setup, document its domain and implement the agreed initial functionality. Use for a new service, not changes to an existing one.
---

# Initialize a service

Read [the shared development workflow](../../references/development-workflow.md)
and service-template/docs/microservice-standards.md.

## Locate and validate

Locate sibling service-template, prod-setup and local-setup checkouts and verify
their PopKult origins. schema/go-common may be fetched as versioned Go modules.
Confirm the service name is lowercase kebab-case and identify its existing GitHub
repository. Preserve actual casing on disk/GitHub, using the internal kebab-case
name for module/deployment/DB names only after checking the existing convention.
If no remote repo exists, create it only when that is within the user's request.

Inspect an existing target's origin and contents. An empty clone may be used;
an existing service or unrelated directory is a conflict to resolve. Preserve
local work. Create a feature branch before generating files, never commit to main.

## Scaffold

Resolve scripts/copy-and-rename.sh relative to this SKILL.md and run it with:

```text
copy-and-rename.sh <workspace>/service-template <target> service-template <name>
```

The script merges into an empty git checkout, preserving .git and .idea. Validate
the target yourself before invoking it; the script cannot decide that it is empty.
For a fresh directory initialize git, set origin, and create the feature branch
before committing. Verify the copied service builds, vets and passes tests.
Ensure copied AGENTS.md describes the new service rather than the template.

## Define the service

Settle GraphQL topology: single BFF, federated subgraph, or no GraphQL yet.
Clarify purpose, owned entities, single-operation use cases, gRPC/external calls,
Kafka producers/consumers and sensitive data. Record these after the README title;
remove inherited template-only claims and setup instructions that no longer apply.
Do not repeat questions already answered in the request.

## Register and implement

- Copy prod-setup/services/service-template to services/<name> using the same
  rename helper. Adjust resources/env/secrets; replace placeholder Secrets with
  the project's sealed-secret process before enabling deployment. Register its
  Argo CD Application. The template is a pattern and is not itself deployed.
- Preserve Rollout canary analysis/pause and scrape annotations, the migrate
  Sync hook (config/secrets wave -1, migrations 0, server/relay 1), migrations
  from the release image, data-gateway hostnames and real Kafka brokers.
- Add local compose server/migrate/relay blocks and numbered postgres-init SQL.
  Use the target's actual directory casing in build.context, existing netrc build
  secret and unused host ports. Existing volumes need manual CREATE DATABASE;
  do not wipe them to initialize one service. Add Kafka topics and metric targets.
- Validate compose configuration. Observability sources live in local-setup;
  regenerate mirrored prod configs with prod-setup/scripts/sync-observability-configs.py
  when relevant. Production Prometheus discovers annotated pods.
- Follow [add-feature](../add-feature/SKILL.md) for the agreed business logic,
  reusing the context and requirements above. Run its relevant checks and report
  all related branches/PRs. Deployment happens only within separately authorized scope.
