---
name: add-feature
description: Implement features in existing PopKult Go services or admin frontends, including required contract and infrastructure changes. Use for new or extended functionality; use init-service or init-frontend for a new repository.
---

# Add a feature

Read [the shared development workflow](../../references/development-workflow.md).

1. Identify the target repository. For Go, read README.md and its own
   docs/microservice-standards.md; for a frontend, read its README, package.json,
   vendored schema and existing UI conventions. Confirm what is implemented in code.
2. Clarify missing requirements and compare them with the documented domain.
   Reuse decisions already made in this conversation. For a first GraphQL surface,
   settle single BFF vs federation vs no GraphQL before wiring it. Identify new
   sensitive fields and their required encryption/redaction.
3. Plan coherent changes across domain/use cases, repositories, entrypoints,
   migrations, schema, other services and prod/local configuration as needed.
   Include observability and a meaningful verification plan in the feature.
4. Implement on feature branches. Keep use cases single-purpose with Execute,
   constructor DI in registry, transport/domain error mappings and thin entrypoints.
   For an admin frontend use the repository's npm checks instead of Go checks;
   surface missing backend capabilities rather than faking them in the client.
5. Verify and update business docs. Complete required cross-service work within
   the agreed scope; report dependencies on schema tags or separately deployed APIs.
6. Report or open PRs according to the user's existing authorization.
