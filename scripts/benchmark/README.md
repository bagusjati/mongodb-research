# Benchmark skenario JMeter di GCP

Tiap konfigurasi (Standalone, Replica, Sharded, Sharded Replica) berjalan sebagai container di satu VM bersama
aplikasi Go, dan JMeter di VM terpisah pada zona yang sama. Kode aplikasi dan compose adalah kode asli
(empat konfigurasi di `app/`), dengan tiga tambahan: variabel `MONGO_URI` untuk uji terisolasi, variabel `APP_DIR`
(path absolut direktori aplikasi di VM, ditulis ke `.env` oleh `20_deploy.sh`), dan image MongoDB dikunci ke satu tag (`MONGO_IMAGE`).

Semua parameter ada di `env.sh` dan dapat ditimpa lewat variabel lingkungan. `PROJECT_ID` wajib diisi.

Urutan:
```
export PROJECT_ID=<id project>
export REPO_ROOT=<path absolut repository>
S=$REPO_ROOT/scripts/benchmark
bash "$S/10_provision.sh"                 # VM aplikasi + VM JMeter
bash "$S/11_push_jmx.sh"                  # test plan ke VM JMeter
for c in $CONFIGS; do bash "$S/20_deploy.sh" $c; done
bash "$S/40_meta.sh"                      # versi, ulimit, status shard
bash "$S/30_run.sh" standalone users 100 1 # uji asap
RUNS=5 bash "$S/31_short_all.sh"          # skenario users + payload, 5 run, semua konfigurasi
for r in 1 2 3; do bash "$S/32_requests_parallel.sh" $r; done   # skenario total request, 3 pass paralel
# uji terisolasi: Replica dengan w:1, dan pool driver dinaikkan
bash "$S/20_deploy.sh" replica "mongodb://mongo1:27017,mongo2:27018,mongo3:27019/?replicaSet=rs0&w=1"
for r in 1 2 3; do bash "$S/30_run.sh" replica requests 100000 $((r+10)); done      # run 11-13 = varian w:1
bash "$S/20_deploy.sh" standalone "mongodb://mongodb:27017/?maxPoolSize=1000"
for r in 1 2 3; do bash "$S/30_run.sh" standalone users 100000 $((r+10)); done      # run 11-13 = varian pool 1000
python3 "$S/50_analyze.py" "$OUT_DIR"
bash "$S/90_teardown.sh"
```
`run_main.sh` menjalankan seluruh urutan di atas.

Uji konsistensi replikasi memakai skrip terpisah (`$REPO_ROOT/scripts/consistency`), dijalankan lebih dahulu atau sesudahnya
bila kuota CPU regional terbatas.
