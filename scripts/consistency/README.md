# Uji konsistensi replikasi lintas region di GCP

Dua VM, primary dan secondary, di dua region berbeda, masing-masing menjalankan satu container mongod
dalam satu replica set. Timestamp dicatat dalam epoch milidetik di sisi aplikasi, jam disinkronkan dengan chrony.

Semua parameter ada di `env.sh` dan dapat ditimpa lewat variabel lingkungan. `PROJECT_ID` wajib diisi.

## Urutan
```
export PROJECT_ID=<id project>
export REPO_ROOT=<path absolut repository>
S=$REPO_ROOT/scripts/consistency
bash "$S/01_provision.sh"          # buat 2 VM + firewall, tunggu setup selesai
bash "$S/03_init_rs.sh"            # rs.initiate, cek status, ukur RTT (ping)
bash "$S/04_run_scenario.sh" baseline 1          # uji coba satu run
RUNS=5 N=1000 RATE=100 bash "$S/05_run_all.sh"   # semua skenario x 5 run
python3 "$S/06_analyze.py" "$OUT_DIR"
bash "$S/99_teardown.sh"           # hapus VM dan firewall
```
`run_cons.sh` menjalankan seluruh urutan di atas.

## Skenario
`baseline`, `delay` (tc qdisc netem `DELAY_MS` pada lalu lintas primary ke secondary), `cpu50`, `cpu10`, `cpu1`
(docker update --cpus pada container mongod di secondary, dihitung dari `VCPUS`).
Folder hasil di `results/consistency` memakai nama `delay1000` untuk skenario delay 1.000 ms.

## Keluaran per run
- `visible_<run>.csv`: seq, t_insert_ms, t_visible_ms (dicatat di secondary)
- `insert_<run>.csv`: seq, t_insert_ms (dicatat di primary)
- `ntp_<run>_*.txt`: offset jam chrony di kedua VM sebelum dan sesudah run
- `summary.csv`: rata-rata, simpangan baku antar-run, median, p95, maksimum lag per skenario
