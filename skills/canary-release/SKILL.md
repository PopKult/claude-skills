---
name: canary-release
description: Inspect PopKult production Argo Rollouts, compare canary and stable health, and promote or abort with explicit authorization. Use for release monitoring and rollout actions; changing manifests belongs in prod-setup.
---

# canary-release

A release is: a PR in `prod-setup` bumps an image tag, the user merges it,
Argo CD syncs, and the service's Rollout starts a canary. This skill babysits
that rollout and gets a human decision at the pause. It changes the cluster
only through `promote` and `abort`, and only within explicit authorization in this conversation. A request to
inspect a canary authorizes read-only inspection; a request to abort a named
release authorizes that abort. Do not ask again for an action already authorized.
Before a new promotion decision, show the health snapshot and manual-check result.

## 0. Preflight

- `kubectl argo rollouts version` must work. If not: `brew install argoproj/tap/kubectl-argo-rollouts`.
- `export KUBECONFIG=<prod-setup>/ansible/kubeconfig/popkult.yaml` (the prod cluster kubeconfig).
  Confirm with `kubectl get rollout -n popkult`.
- Ask which service if the user did not say. Rollout names: `juicer`,
  `mobile-api`, `progress-calculator`, `task-grader`.
  `service-template` is an undeployed pattern; do not assume a live Rollout exists.

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
secrets changed with it. The outbox relay is an ordinary Deployment, not part
of the server's paused canary: check its rollout, logs and Kafka error/lag metrics
separately. Kafka consumer assignment and long-lived gRPC connections do not
promise an exact 50% request split. task-grader's analysis watches gRPC, so also
check its Kafka grading path and GraphQL operator API where relevant.
Pods do not restart on ConfigMap changes - if the
release depends on a ConfigMap, say that explicitly.

## 3. Watch until the pause

1. Run the snapshot: `python3 <skill-directory>/scripts/canary-status.py <rollout>` (resolve the absolute skill directory first). It is read-only: it opens a short-lived
   port-forward to Prometheus on 127.0.0.1 and closes it at exit.
2. Also `kubectl argo rollouts get rollout <rollout> -n popkult` for the tree.
3. The analysis takes about 5 minutes. Poll every ~60s (snapshot or `get`);
   do not sleep in a tight loop. Stop at one of:
   - **Paused** (`CanaryPauseStep`, analysis Successful) -> §4.
   - **Degraded / aborted / analysis Failed** -> §6, without asking.
   - A canary pod in CrashLoopBackOff or not ready for >3 min -> show
     `kubectl logs` / `describe` and recommend abort.
   Investigate startup restarts; initial network-policy programming may delay
   Postgres access, but do not assume every restart is harmless.

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

- `juicer` (admin): create a harvest draft, open it, edit, paste a transcript, a few times in a row. During the mixed window a draft stored in one pod's memory may "not be found" on the other - since drafts live in Redis this must not happen; if it does, recommend abort
  and execute it only if authorized.
- `mobile-api`: log in from the app (and a fresh Google login), open a lesson list. A bad JWKS shows as UNAUTHENTICATED - check `rejected` reasons in the pod logs.
- `progress-calculator` / `task-grader`: ask the user to submit one task / view progress in the app, then check the canary pod logs for that request.

## 5. Ask, then act

Present the summary (numbers and manual-check result). If promotion has not
already been explicitly authorized, ask once: "Promote <service> to 100%?"
Act only within authorization for this specific promotion:

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
push/open a PR only when the user has authorized that work.

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
