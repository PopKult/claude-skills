---
name: canary-release
description: Drive a PopKult canary release on the prod k3s cluster (Argo Rollouts) from merge to full rollout - watches the rollout and its automatic Prometheus analysis, prints a canary-vs-stable health snapshot (error ratio, p95 latency, req/s, memory, restarts, log errors), tells the person exactly what to check by hand for that service, and only after an explicit yes promotes the release or aborts it. Use this whenever the user says a prod-setup PR with a new image tag is merged and asks to roll it out, promote, resume or continue a canary, abort or roll back a release, or asks "how is the canary doing" for juicer, mobile-api, progress-calculator, task-grader or service-template. Do NOT use it to change rollout manifests or analysis templates (that is a prod-setup change) and never use it for Promote-Full.
---

# canary-release

A release is: a PR in `prod-setup` bumps an image tag, the user merges it,
Argo CD syncs, and the service's Rollout starts a canary. This skill babysits
that rollout and gets a human decision at the pause. It changes the cluster
only through `promote` and `abort`, and only after the user says so in this
conversation.

## 0. Preflight

- `kubectl argo rollouts version` must work. If not: `brew install argoproj/tap/kubectl-argo-rollouts`.
- `export KUBECONFIG=<prod-setup>/ansible/kubeconfig/popkult.yaml` (the prod cluster kubeconfig).
  Confirm with `kubectl get rollout -n popkult`.
- Ask which service if the user did not say. Rollout names: `juicer`,
  `mobile-api`, `progress-calculator`, `task-grader`, `service-template`.

## 1. How the rollout is built (so you can explain it)

`setWeight: 50` -> Prometheus analysis (gRPC error ratio for the new pods; for
`mobile-api` the GraphQL error ratio; 5 checks, one per minute, fails above
5%; no traffic counts as a pass) -> `pause: {}` until someone promotes.
Only `mobile-api` has Traefik traffic weights; for the others the canary
share is about the replica ratio. A failed analysis aborts by itself and
traffic goes back to the stable version.

An empty analysis ("no traffic = pass") proves nothing about correctness. The
manual check in §4 is the real gate.

## 2. Find out what is being released

Look at the merged prod-setup change (`git log -3 -- services/<service>` in
`prod-setup`) and the service repo's commits between the old and new tag, so
you can say in a sentence what changed, whether there is a migration (the
`<service>-migrate-*` Job runs before the rollout), and whether config or
secrets changed with it. Pods do not restart on ConfigMap changes - if the
release depends on a ConfigMap, say that explicitly.

## 3. Watch until the pause

1. Run the snapshot: `python3 scripts/canary-status.py <rollout>` (path
   relative to this skill). It is read-only: it opens a short-lived
   port-forward to Prometheus on 127.0.0.1 and closes it at exit.
2. Also `kubectl argo rollouts get rollout <rollout> -n popkult` for the tree.
3. The analysis takes about 5 minutes. Poll every ~60s (snapshot or `get`);
   do not sleep in a tight loop. Stop at one of:
   - **Paused** (`CanaryPauseStep`, analysis Successful) -> §4.
   - **Degraded / aborted / analysis Failed** -> §6, without asking.
   - A canary pod in CrashLoopBackOff or not ready for >3 min -> show
     `kubectl logs` / `describe` and recommend abort.
   A canary pod with 1-2 restarts in the first seconds is normal: a new pod
   cannot reach Postgres for its first moments.

## 4. At the pause: show the numbers, say what to look at

Run the snapshot again and present it as a short table. Then give the
reading guide:

| Signal | Fine | Stop and look |
|---|---|---|
| canary errors | <= stable, well under 1% | above stable, or any rise over time |
| p95 latency | within ~1.5x of stable | clearly worse than stable |
| req/s on canary | > 0 (it is getting traffic) | 0: the analysis proved nothing, do the manual check |
| memory | similar to stable | climbing between two snapshots |
| restarts | no new ones after start | growing |
| log errors | none new | repeated ERROR lines, "not found", "connection refused", "unauthenticated" |

If req/s on the canary is ~0 the numbers are meaningless: say so plainly.

Then the **manual check by service** (tell the user to do it now, while old
and new pods serve side by side):

- `juicer` (admin): create a harvest draft, open it, edit, paste a transcript, a few times in a row. During the mixed window a draft stored in one pod's memory may "not be found" on the other - since drafts live in Redis this must not happen; if it does, abort.
- `mobile-api`: log in from the app (and a fresh Google login), open a lesson list. A bad JWKS shows as UNAUTHENTICATED - check `rejected` reasons in the pod logs.
- `progress-calculator` / `task-grader`: ask the user to submit one task / view progress in the app, then check the canary pod logs for that request.
- `service-template`: nothing user-visible; rely on the numbers.

## 5. Ask, then act

Ask once: "Promote <service> to 100%?" with the summary (numbers, manual check
result). Only on an explicit yes:

```
kubectl argo rollouts promote <rollout> -n popkult
```

Then watch until `Healthy`, run the snapshot once more, and confirm that old
pods are gone and nothing new is restarting. If the user says wait, leave it
paused - a pause has no timeout.

**Never** run `promote --full` (skips the analysis), never edit the Rollout
by hand, and never promote on the strength of numbers alone when canary req/s
is ~0.

## 6. Abort / rollback

On a failed analysis Argo already aborted: confirm traffic is on the stable
version and show why (`kubectl get analysisrun -n popkult` and `describe` the
failed one). If the user wants to stop a healthy-looking canary:

```
kubectl argo rollouts abort <rollout> -n popkult
```

An aborted Rollout stays "Degraded" until the tag is fixed or reverted in git;
Argo CD selfHeal will not retry it by itself. To retry the same version:
`kubectl argo rollouts retry rollout <rollout> -n popkult`. Tell the user the
fix goes through a prod-setup PR (revert the tag or bump to a fixed one) -
do not push it yourself without their approval.

Database migrations ran before the canary and are not rolled back; this is
why migrations must stay backward compatible (see `add-feature`).

## 7. Report

End with: what was released (old -> new tag), the final snapshot numbers, the
state (`Healthy` on the new tag, or aborted and why), and any follow-up (an
alert that fired, an error seen in the logs).

## Optional: a local dashboard

`kubectl argo rollouts dashboard -n popkult` serves a read/act UI on
http://localhost:3100 with the same Promote/Abort buttons. Fine for the user
to look at; this skill's flow does not need it.
