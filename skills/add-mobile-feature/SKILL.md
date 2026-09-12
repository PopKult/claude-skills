---
name: add-mobile-feature
description: Add new functionality to an EXISTING PopKult Kotlin Multiplatform Mobile (KMM) app — reads the repo's own business.md and technical doc first, interviews the user until the request is genuinely clear (explicitly asking for a UI design when a UI module is involved, for the analytics events the feature should send, and for how the feature is onboarded to users), plans the shared/platform module split as a proposal the user can push back on before it's final, demonstrates a test plan before writing any code, then implements the change as small reviewable commits (4-6 files, 50-100 changed lines each) with a stop-and-review gate after every commit. Use this whenever the user wants to add, implement, build, or extend a feature/screen/flow in a mobile app that already exists — phrases like "add X to the app", "implement Y in the mobile app", "the app needs to support Z" — even if they don't name this skill explicitly. Do NOT use this for scaffolding a brand-new mobile app (no init-mobile-app skill exists yet — ask the user how they want that done) or for pure bug fixes with no new functionality.
---

# add-mobile-feature

Turns "add `<functionality>` to the app" into a small set of reviewable,
individually-verified commits on a feature branch — grounded in what the
app's own business doc and technical doc say, not a guess at either.

This skill never touches `main` directly and never pushes anything —
everything happens on a local feature branch, reported at the end, left
for the user to push when they're ready. It also never chains multiple
commits without stopping: **every commit gets its own review gate**, even
if the user already approved the overall module plan — approving the
plan is not the same as approving the diff.

## Phase 0 — locate context

Confirm you're in the target mobile app's repo (a Kotlin Multiplatform
project — `commonMain` shared module plus `androidMain`/`iosMain`
platform code, or however this repo actually lays it out — don't assume
a shape you haven't confirmed). If it's not clear which repo, ask.

Find and read this repo's **business.md** and its **technical doc** —
these already exist in the repo (check the root and `docs/` first; ask
the user where they live if you can't find them, don't guess a
convention). Treat both as authoritative for this run:

- **business.md** — what the app is for, its domain, its existing
  features. Your baseline for judging whether the new request is a
  natural extension or something that conflicts with documented scope.
- **Technical doc** — the module boundaries, architecture conventions
  (DI, networking, navigation, `expect`/`actual` usage), and — important
  for Phase 2 — whatever analytics convention already exists (an event
  registry, a wrapper class, a naming scheme). Follow the existing
  convention for new analytics events; don't invent a parallel one.

If the request conflicts with business.md, or technical conventions the
doc describes, say so now rather than silently reconciling it later.

## Phase 1 — clarify what to add

Open-ended interview. Figure out what the user actually wants — keep
asking follow-ups until you could correctly describe the feature back to
someone who hasn't seen this conversation. Three things to ask for
explicitly, every time they apply, rather than waiting for the user to
volunteer them:

- **UI design**, if the feature involves a new or changed UI module —
  ask for a description of the screens/flow (layout, states, navigation
  in/out), a reference mockup, or an existing design source. Don't
  invent a UI design yourself and present it as settled; if the user has
  no design yet, that's fine, but say plainly that Phase 2's plan will
  treat the UI as a placeholder to be nailed down before that module's
  commit.
- **Analytics actions** the feature should send — which user actions
  trigger an event, and what each event should be named/carry, per the
  convention Phase 0 found in the technical doc. If the app doesn't
  track analytics for anything like this yet, ask whether this feature
  should be the first, and if so, confirm the convention before using it
  anywhere.
- **Onboarding** for the feature — how a user is introduced to it the
  first time they'd encounter it: nothing (it's discoverable on its
  own), a one-time tooltip/coach-mark, a modal/walkthrough, an entry in
  an existing onboarding flow, or a changelog/"what's new" surface,
  whichever the app already has precedent for. If the feature changes
  existing behavior rather than adding something new, ask whether
  returning users need to be told at all. Don't assume "none" just
  because the user didn't mention it.

## Phase 2 — plan the modules, converge with the user

Sketch, at a conceptual level, which modules the feature touches and how
they fit together — e.g. "a new use case in the shared domain module,
a repository method backed by a new network call, one new screen in the
Android UI module, its iOS counterpart, a coach-mark shown the first
time that screen opens, and an analytics event fired on submit." The
goal is that the user understands the shape of the change, not a
file-by-file spec — save the detail for Phase 3. Include the onboarding
mechanism from Phase 1 as its own piece of the plan, not folded silently
into the UI module — it's usually its own small piece of state (a
"seen this before" flag) and its own commit.

If the user pushes back or asks to change something, don't just comply —
weigh it against business.md/technical doc and what you already know
about the codebase, and say plainly if a suggested change conflicts with
either or seems like a worse fit than the current plan, with your
reasoning. If the user still wants it after hearing the concern, take
their call and move on — the point is to surface the tradeoff once, not
to relitigate it. Iterate like this until the plan is genuinely settled,
then restate the final version before moving to Phase 3.

Update business.md's feature/domain description to cover the new
functionality once the plan is settled — keep the doc and the code from
diverging.

## Phase 3 — demonstrate the test plan

Before writing any implementation code, present what the tests will
cover, mapped to the modules from Phase 2 — not the test code itself,
the coverage plan. Typical shape for a KMM feature:

- **Shared/`commonMain` logic** — unit tests for the new use case /
  domain logic, using whatever the repo's existing shared-module test
  setup is (`kotlin.test`, MockK, etc.).
- **Platform-specific code** — Android unit/instrumented tests and, if
  the repo has iOS tests, their counterpart, for any `expect`/`actual`
  implementation or platform UI logic.
- **UI**, if a UI module is involved — whatever the repo's existing
  pattern is for UI-level tests (Compose UI tests, snapshot tests, etc.).
  If the UI design from Phase 1 is still a placeholder, say which tests
  depend on it being finalized first.
- **Analytics** — a test (or explicit manual-check note, if the repo has
  no precedent for testing analytics calls) confirming each event from
  Phase 1 fires on the right trigger with the right payload.
- **Onboarding** — if Phase 1 settled on a coach-mark/modal/flow entry,
  a test that it shows exactly once (the "seen" flag persists and is
  respected) and that dismissing/completing it behaves correctly. If it
  settled on "none," no coverage needed here.

Get the user's go-ahead on this coverage before Phase 4. If the repo
has no test setup at all for one of these layers, say so and ask whether
to add minimal scaffolding for it or skip coverage there for now — don't
silently skip.

## Phase 4 — branch and implement, gated per commit

Create a feature branch named `add-<feature-slug>`. Never commit to
`main`.

Break the implementation into commits of **4-6 files, 50-100 changed
lines each** — a guideline for how to slice the work, not a license to
leave the tree broken between commits. For each commit, in order:

1. Implement the files.
2. Verify: the repo's build (e.g. `./gradlew build`) and the relevant
   tests from Phase 3 for what this commit touches — all clean before
   the commit counts as done. Don't move on and fix it "in the next
   commit."
3. Commit, message naming what the commit does (e.g.
   `git commit -m "Add ReserveSeat use case to shared module"`).
4. Show the diff to the user.
5. **Stop.** Wait for explicit go-ahead before starting the next commit —
   every commit, not just the risky-looking ones.

## Phase 5 — report, don't push

Summarize every commit created on the branch — what changed and why,
referencing the module plan from Phase 2 and the test coverage from
Phase 3. State plainly that nothing has been pushed and no PR has been
opened. Wait for the user to explicitly ask before running `git push` —
don't lead with "should I push?" either, just report status and let them
decide when.
