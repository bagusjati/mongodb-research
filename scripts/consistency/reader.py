#!/usr/bin/env python3
"""Membaca langsung dari secondary dan mencatat kapan tiap dokumen pertama kali terlihat.
Dipanggil di VM secondary sebelum inserter dimulai. Keluaran CSV: seq,t_insert_ms,t_visible_ms"""
import sys, os, time, csv
from pymongo import MongoClient, ReadPreference
# argumen (semua wajib): run_id N timeout_s out_dir port
run_id, n, timeout_s = sys.argv[1], int(sys.argv[2]), float(sys.argv[3])
if len(sys.argv) != 6: raise SystemExit("argumen: run_id N timeout_s out_dir port")
out_dir, port = sys.argv[4], sys.argv[5]
client = MongoClient(f"mongodb://127.0.0.1:{port}/?directConnection=true",
                     read_preference=ReadPreference.SECONDARY_PREFERRED)
col = client.bench.consistency
out = open(os.path.join(out_dir, f"visible_{run_id}.csv"), "w", newline="")
w = csv.writer(out); w.writerow(["seq", "t_insert_ms", "t_visible_ms"])
seen, last_seq, t_start = 0, -1, time.time()
while seen < n and time.time() - t_start < timeout_s:
    docs = list(col.find({"run": run_id, "seq": {"$gt": last_seq}}, {"seq": 1, "t_insert_ms": 1}).sort("seq", 1))
    t_vis = time.time_ns() // 1_000_000
    for d in docs:
        w.writerow([d["seq"], d["t_insert_ms"], t_vis]); seen += 1; last_seq = d["seq"]
    if not docs: time.sleep(0.001)
out.close()
print("visible", seen, "of", n)
