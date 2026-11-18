#!/usr/bin/env python3
"""Mengolah semua .jtl dan stats_*.csv di OUT_DIR.
Keluaran: per_run.csv (satu baris per run), summary.csv (mean dan sd antar-run per sel),
errors.csv (jenis error per sel), resources.csv (CPU dan memori per container per sel)."""
import sys, os, csv, glob, re, statistics as st
from collections import defaultdict, Counter
root = sys.argv[1]
def pct(xs, p):
    xs = sorted(xs); k = (len(xs)-1)*p; f = int(k); c = min(f+1, len(xs)-1)
    return xs[f] + (xs[c]-xs[f])*(k-f)
per_run, errors, res = [], [], []
cells = defaultdict(list)
for jtl in sorted(glob.glob(os.path.join(root, "*", "*", "*.jtl"))):
    base = os.path.basename(jtl)[:-4]
    m = re.match(r"(\w+?)_(users|requests|payload)_([\w.]+)_run(\d+)$", base)
    if not m: continue
    cfg, scen, level, run = m.group(1), m.group(2), m.group(3), int(m.group(4))
    el, ts_min, ts_end, nerr, msgs = [], None, None, 0, Counter()
    with open(jtl, newline="") as fh:
        for row in csv.DictReader(fh):
            try: t = int(row["timeStamp"]); e = int(row["elapsed"])
            except: continue
            el.append(e); ts_min = t if ts_min is None else min(ts_min, t); ts_end = max(ts_end or 0, t+e)
            if row["success"] != "true":
                nerr += 1; msgs[(row["responseCode"] or "?")+" "+(row["responseMessage"] or "")[:60]] += 1
    if not el: continue
    n = len(el); dur = max(ts_end - ts_min, 1)/1000
    r = dict(config=cfg, scenario=scen, level=level, run=run, samples=n, error_pct=round(100*nerr/n, 2),
             avg_ms=round(st.mean(el), 2), min_ms=min(el), max_ms=max(el), p50_ms=round(pct(el,.5),1),
             p90_ms=round(pct(el,.9),1), p95_ms=round(pct(el,.95),1), p99_ms=round(pct(el,.99),1),
             throughput_rps=round(n/dur, 2), duration_s=round(dur,1))
    per_run.append(r); cells[(cfg,scen,level)].append(r)
    for k, v in msgs.most_common(5): errors.append(dict(config=cfg, scenario=scen, level=level, run=run, error=k, count=v))
    stats = os.path.join(os.path.dirname(jtl), f"stats_{base}.csv")
    if os.path.exists(stats):
        cpu, mem = defaultdict(list), defaultdict(list)
        for line in open(stats):
            p = line.strip().split(",")
            if len(p) < 4: continue
            try: cpu[p[1]].append(float(p[2].rstrip("%"))); mem[p[1]].append(p[3].split("/")[0].strip())
            except: pass
        def mib(s):
            v = float(re.sub(r"[A-Za-z]", "", s)); return v*1024 if "GiB" in s else v
        for name in cpu:
            res.append(dict(config=cfg, scenario=scen, level=level, run=run, container=name,
                            cpu_mean_pct=round(st.mean(cpu[name]),1), cpu_peak_pct=max(cpu[name]),
                            mem_peak_mib=round(max(mib(x) for x in mem[name]),0)))
def write(name, rows):
    if not rows: return
    with open(os.path.join(root, name), "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
write("per_run.csv", per_run); write("errors.csv", errors); write("resources.csv", res)
summary = []
for (cfg, scen, level), rs in sorted(cells.items()):
    row = dict(config=cfg, scenario=scen, level=level, runs=len(rs))
    for k in ("avg_ms","p95_ms","p99_ms","max_ms","error_pct","throughput_rps"):
        xs = [r[k] for r in rs]; row[k+"_mean"] = round(st.mean(xs),2); row[k+"_sd"] = round(st.stdev(xs),2) if len(xs)>1 else 0.0
    summary.append(row)
write("summary.csv", summary)
for r in summary:
    print(f"{r['config']:15s} {r['scenario']:8s} {r['level']:>7s} n={r['runs']} avg={r['avg_ms_mean']:>9.1f}±{r['avg_ms_sd']:<7.1f} p95={r['p95_ms_mean']:>8.0f} err={r['error_pct_mean']:5.1f}% thr={r['throughput_rps_mean']:>8.1f}±{r['throughput_rps_sd']:.1f}")
