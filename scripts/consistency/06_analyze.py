#!/usr/bin/env python3
"""Menghitung lag = t_visible_ms - t_insert_ms per run dan per skenario.
Pemakaian: python3 06_analyze.py <OUT_DIR> ["skenario ..."]  -> mencetak ringkasan dan menulis summary.csv"""
import sys, csv, glob, os, statistics as st
out_dir = sys.argv[1]
scenarios = sys.argv[2].split() if len(sys.argv) > 2 else os.environ.get("SCENARIOS", "baseline delay1000 delay cpu50 cpu10 cpu1").split()
rows = []
for scen in scenarios:
    per_run = []
    for f in sorted(glob.glob(os.path.join(out_dir, scen, "visible_*.csv"))):
        lags = [int(r["t_visible_ms"]) - int(r["t_insert_ms"]) for r in csv.DictReader(open(f))]
        if not lags: continue
        lags.sort()
        per_run.append({"run": os.path.basename(f), "n": len(lags), "mean": st.mean(lags),
                        "median": st.median(lags), "p95": lags[int(0.95 * (len(lags) - 1))], "max": lags[-1]})
    if not per_run: continue
    means = [r["mean"] for r in per_run]
    rows.append([scen, len(per_run), round(st.mean(means), 1),
                 round(st.stdev(means), 1) if len(means) > 1 else 0.0,
                 round(st.mean([r["median"] for r in per_run]), 1),
                 round(st.mean([r["p95"] for r in per_run]), 1),
                 max(r["max"] for r in per_run)])
hdr = ["scenario", "runs", "mean_lag_ms", "sd_between_runs_ms", "median_ms", "p95_ms", "max_ms"]
print("\t".join(hdr))
for r in rows: print("\t".join(str(x) for x in r))
with open(os.path.join(out_dir, "summary.csv"), "w", newline="") as fh:
    w = csv.writer(fh); w.writerow(hdr); w.writerows(rows)
