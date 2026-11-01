---
name: init-frontend
description: Create a PopKult operator admin frontend for an existing service with a GraphQL API using React, Vite, TypeScript, Apollo and nginx. Register the new frontend in the shared infrastructure repositories.
---

# Initialize an admin frontend

Read [the shared development workflow](../../references/development-workflow.md)
and service-template/docs/microservice-standards.md section 2.3.

## Context and decisions

Locate and verify the service, schema, prod-setup and local-setup repositories.
Read the backend README and schema/graphql/<service>.graphqls. A frontend needs
a real GraphQL surface; if absent, explain the required backend work first.
Confirm the target repository's real name/origin: juicer-frontend, for example,
lives in Juicer-Adm. Never derive an existing repo name solely from a deploy name.
Use an empty target clone or a fresh directory; preserve local work and resolve
collisions. Create feature branches for scaffold and registration alike.

Confirm the operator workflow, entities to expose, list/detail fields, filters,
mutations, pagination, empty/error/loading states and auth model. Determine whether
GraphQL is direct or federated. Reuse the existing VPN-only edge pattern when it
fits the request; never expose an unauthenticated admin board publicly by default.

## Scaffold and connect

Resolve scripts/scaffold-frontend.sh relative to this SKILL.md:

```text
scaffold-frontend.sh <target-directory> <service>
```

The scaffold is React + Vite + TypeScript + Apollo Client, GraphQL Code Generator
client preset, vendored SDL and a static nginx image. It leaves auth, proxying,
deployment and image publication to this workflow. It must find the real sibling
schema; do not ship its fallback placeholder. Review dependency compatibility
before npm install, then codegen, lint, typecheck and build.

Prefer browser requests to same-origin /query, as Juicer-Adm does: Vite proxies
to the locally published backend, nginx proxies to GRAPHQL_UPSTREAM in containers.
Render GRAPHQL_ENDPOINT into config.js at startup, not build time, and prevent
config.js caching. A browser cannot resolve Kubernetes or compose service DNS;
only the proxy uses those addresses. Wire the agreed auth flow, if any.

Document requirements, stack, schema sync, runtime config and deployment. Add
an AGENTS.md with the real frontend checks and source-of-truth paths.

## Register and implement

- Add prod-setup/services/<frontend>/deployment.yaml: nginx Deployment, Service,
  runtime ConfigMap, HTTP readiness/liveness, resources sized for static serving.
  Use a pinned image tag for releases, not latest. Add the Argo CD Application
  and VPN-only ingress/NetworkPolicy as required by the chosen access pattern.
  A frontend has no migration Job or outbox relay.
- Add the local compose build with the actual sibling directory, unused host
  port, backend dependency, /query endpoint and internal proxy upstream. No private
  Go module build secret or database is needed. Validate docker compose config.
- Ensure CI runs npm ci, codegen, lint, typecheck and build, and verifies images
  on PRs / publishes SHA-tagged images on main, following Juicer-Adm's current CI.
- Follow [add-feature](../add-feature/SKILL.md) with frontend checks to implement
  the agreed views. Reuse the interview; do not impose Go checks on a frontend.
  Include required backend/schema work in the agreed scope or explain the exact
  dependency. Audit logging is a backend decision, not frontend boilerplate.
- Verify and report all related branches or PRs within the user's authorization.
