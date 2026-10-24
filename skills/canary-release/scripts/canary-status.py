#!/usr/bin/env python3
"""Read-only health snapshot of one PopKult Rollout: canary vs stable.

Usage: canary-status.py <rollout> [--namespace popkult]

Needs kubectl (KUBECONFIG pointing at the prod cluster) and the
kubectl-argo-rollouts plugin. Prometheus is reached through a temporary
`kubectl port-forward` bound to 127.0.0.1 and closed on exit. Nothing is
modified in the cluster.
"""
import argparse, json, subprocess, sys, time, urllib.parse, urllib.request, socket, shutil

GRPC_ERR = ',code=~"Internal|Unknown|Unavailable|DataLoss|DeadlineExceeded"'
GQL_ERR = ',status="error"'

def sh(*cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.returncode, r.stdout, r.stderr

def kjson(*args):
    rc, out, err = sh("kubectl", *args, "-o", "json")
    if rc:
        sys.exit(f"kubectl {' '.join(args)} failed: {err.strip()}")
    return json.loads(out)

def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]

class Prom:
    def __init__(self, port):
        self.base = f"http://127.0.0.1:{port}"
    def q(self, expr):
        url = f"{self.base}/api/v1/query?" + urllib.parse.urlencode({"query": expr})
        with urllib.request.urlopen(url, timeout=10) as r:
            res = json.load(r)["data"]["result"]
        return float(res[0]["value"][1]) if res else None

def fmt(v, kind):
    if v is None or v != v:
        return "-"
    if kind == "pct":
        return f"{v*100:.2f}%"
    if kind == "ms":
        return f"{v*1000:.0f} ms"
    if kind == "mb":
        return f"{v/1048576:.0f} MB"
    return f"{v:.2f}"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("rollout")
    ap.add_argument("--namespace", "-n", default="popkult")
    a = ap.parse_args()
    ns, name = a.namespace, a.rollout

    ro = kjson("get", "rollout", name, "-n", ns)
    st = ro["status"]
    canary_hash, stable_hash = st.get("currentPodHash"), st.get("currentPodHash")
    stable_rs = st.get("stableRS")
    print(f"== Rollout {name}: phase={st.get('phase')} message={st.get('message', '')!r}")
    print(f"   step {st.get('currentStepIndex')}/{len(ro['spec']['strategy']['canary']['steps'])} "
          f"canary-hash={canary_hash} stable-hash={stable_rs} abort={st.get('abort', False)}")
    paused = bool(st.get("pauseConditions"))
    in_canary = canary_hash != stable_rs
    if not in_canary:
        print("   Nothing to compare: canary == stable (no release in progress).")

    print("\n== Analysis runs")
    rc, out, _ = sh("kubectl", "get", "analysisrun", "-n", ns, "-l", f"rollouts-pod-template-hash={canary_hash}",
                    "-o", "custom-columns=NAME:.metadata.name,STATUS:.status.phase,AGE:.metadata.creationTimestamp",
                    "--no-headers")
    print(out.strip() or "   (none)")

    print("\n== Pods")
    pods = kjson("get", "pods", "-n", ns, "-l", f"app={ro['spec']['selector']['matchLabels']['app']}")["items"]
    for p in pods:
        h = p["metadata"]["labels"].get("rollouts-pod-template-hash")
        role = "CANARY" if (in_canary and h == canary_hash) else "stable"
        cs = (p["status"].get("containerStatuses") or [{}])[0]
        waiting = (cs.get("state", {}).get("waiting") or {}).get("reason", "")
        print(f"   {p['metadata']['name']:<40} {role:<7} ready={cs.get('ready')} "
              f"restarts={cs.get('restartCount', 0)} {waiting}")

    # Prometheus through a throw-away port-forward.
    port = free_port()
    pf = subprocess.Popen(["kubectl", "port-forward", "-n", "observability", "svc/prometheus",
                           f"{port}:9090", "--address", "127.0.0.1"],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        prom = Prom(port)
        for _ in range(20):
            try:
                prom.q("vector(1)"); break
            except Exception:
                time.sleep(0.5)
        else:
            sys.exit("could not reach Prometheus through port-forward")

        # Pick the instrumentation the service actually exports.
        job = name
        if prom.q(f'count(grpc_server_requests_total{{job="{job}"}})') is not None:
            kind = "grpc"
        elif prom.q(f'count(graphql_operations_total{{job="{job}"}})') is not None:
            kind = "graphql"
        else:
            kind = None
        print(f"\n== Metrics (last 5m, job={job}, protocol={kind})")
        if kind is None:
            print("   no request metrics found for this job"); return

        def sel(metric, h, extra=""):
            return f'{metric}{{job="{job}",rollouts_pod_template_hash="{h}"{extra}}}'
        rows = []
        for label, h in (("canary", canary_hash), ("stable", stable_rs)):
            if label == "canary" and not in_canary:
                continue
            if kind == "grpc":
                tot = f"sum(rate({sel('grpc_server_requests_total', h)}[5m]))"
                err = f"sum(rate({sel('grpc_server_requests_total', h, GRPC_ERR)}[5m]))"
                dur = f"histogram_quantile(0.95, sum by (le) (rate({sel('grpc_server_request_duration_seconds_bucket', h)}[5m])))"
            else:
                tot = f"sum(rate({sel('graphql_operations_total', h)}[5m]))"
                err = f"sum(rate({sel('graphql_operations_total', h, GQL_ERR)}[5m]))"
                dur = f"histogram_quantile(0.95, sum by (le) (rate({sel('graphql_operation_duration_seconds_bucket', h)}[5m])))"
            rps = prom.q(tot)
            e = prom.q(err)
            ratio = (e or 0) / rps if rps else None
            mem = prom.q(f'avg(process_resident_memory_bytes{{job="{job}",rollouts_pod_template_hash="{h}"}})')
            rows.append((label, rps, ratio, prom.q(dur), mem))
        print(f"   {'':<8}{'req/s':>8}{'errors':>10}{'p95':>10}{'memory':>10}")
        for label, rps, ratio, p95, mem in rows:
            print(f"   {label:<8}{fmt(rps,'n'):>8}{fmt(ratio,'pct'):>10}{fmt(p95,'ms'):>10}{fmt(mem,'mb'):>10}")
    finally:
        pf.terminate()

    if in_canary:
        print("\n== Recent canary log errors")
        for p in pods:
            if p["metadata"]["labels"].get("rollouts-pod-template-hash") == canary_hash:
                rc, out, _ = sh("kubectl", "logs", "-n", ns, p["metadata"]["name"], "--since=10m", "--tail=2000")
                bad = [l for l in out.splitlines() if '"level":"ERROR"' in l or '"level":"WARN"' in l]
                print(f"   {p['metadata']['name']}: {len(bad)} ERROR/WARN lines in 10m")
                for l in bad[-5:]:
                    print("     " + l[:240])
    print("\nPaused, waiting for a decision." if paused else "\nNot paused.")

if __name__ == "__main__":
    if not shutil.which("kubectl"):
        sys.exit("kubectl not found")
    main()
