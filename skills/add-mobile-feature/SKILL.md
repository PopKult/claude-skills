---
name: add-mobile-feature
description: Implement features, screens and flows in the existing PopKult Kotlin Multiplatform mobile app. Use its business and technical documents to preserve module boundaries, analytics, onboarding and Android/iOS behavior.
---

# Add a mobile feature

Read [the shared development workflow](../../references/development-workflow.md).

Read business.md, docs/TECHNICAL.md, relevant modules and CI before changing code.
Distinguish the target architecture from the current implementation section.

Clarify missing product decisions: screen layout/states/navigation for UI work,
analytics triggers/payloads using the existing registry, and how users discover
the feature (including whether onboarding is needed). Reuse supplied designs and
decisions. If no design exists, identify what still needs a decision before UI
implementation; do not silently settle a product design on the user's behalf.

Explain the module split and verification before implementation. Common modules
depend on common only; BusinessLogic modules depend on common, never each other;
Screen modules depend on common and BusinessLogic, never other screens. Register
screen factories at the composition root. Preserve Redux/MVI state flow, domain
mappers, design-system components, localized strings and the existing animation
primitives. Keep interrupt results queued until an appropriate interaction boundary.

Plan tests around changed shared logic, platform behavior, UI states, analytics
and onboarding persistence. Use existing test infrastructure; explain any coverage
gap and add scaffolding only when needed for the feature. Preserve auth/account
boundaries in persisted state.

Implement coherent commits on a feature branch without a per-commit approval gate.
If the BFF contract changes, update schema and mobile-api as needed, refresh the
vendored SDL and regenerate Apollo sources. Keep business.md and TECHNICAL.md in
sync. Run relevant module tests and Android/iOS checks, reporting unavailable
toolchains. Report or open PRs within the user's authorization.
