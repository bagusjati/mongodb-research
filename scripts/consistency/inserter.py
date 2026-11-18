#!/usr/bin/env python3
"""Insert N dokumen ke primary dengan timestamp epoch milidetik di sisi aplikasi.
Dipanggil di VM primary. Keluaran CSV: seq,t_insert_ms"""
import sys, os, time, csv
from pymongo import MongoClient
# argumen (semua wajib): run_id N rate out_dir port; rate = dokumen per detik
run_id, n, rate = sys.argv[1], int(sys.argv[2]), float(sys.argv[3])
if len(sys.argv) != 6: raise SystemExit("argumen: run_id N rate out_dir port")
out_dir, port = sys.argv[4], sys.argv[5]
client = MongoClient(f"mongodb://127.0.0.1:{port}/?directConnection=true", w=1)
col = client.bench.consistency
for _ in range(60):
    if client.admin.command("hello").get("isWritablePrimary"): break
    time.sleep(3)
else:
    raise SystemExit("local node is not primary")
interval = 1.0 / rate
out = open(os.path.join(out_dir, f"insert_{run_id}.csv"), "w", newline="")
w = csv.writer(out); w.writerow(["seq", "t_insert_ms"])
t_next = time.time()
for seq in range(n):
    t_ms = time.time_ns() // 1_000_000
    col.insert_one({"run": run_id, "seq": seq, "t_insert_ms": t_ms, "payload": "x" * 512})
    w.writerow([seq, t_ms])
    t_next += interval
    sleep = t_next - time.time()
    if sleep > 0: time.sleep(sleep)
out.close()
print("inserted", n)
