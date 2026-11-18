# MongoDB replication and sharding benchmark

Source code, test plans, scripts and result data for the study *Throughput and Latency Trade-offs of MongoDB Replication and Sharding Strategies with a Cross-Region Replication Consistency Test*.

The experiments were run on Google Cloud Platform in November 2026 with MongoDB 7.0.9, Docker 29.10, Apache JMeter 5.6.3, Java 17 and Go 1.19.

## Layout

| Path | Content |
| --- | --- |
| `app/standalone`, `app/replica`, `app/sharded`, `app/sharded-replica` | The Go (Gin) web application and the Docker Compose deployment of each MongoDB configuration. The code is the application used in the study. The only additions are a `MONGO_URI` environment override (used by the isolated tests), an `APP_DIR` variable that holds the absolute path of the deployed directory (used for the build context and the bind mounts), and a `go mod tidy` step in the Dockerfile. |
| `jmeter/` | The three JMeter test plans (`users.jmx`, `requests.jmx`, `payload.jmx`), the fixed request bodies (0.1 kB, 1 kB, 10 kB) and the generator script. Host and port are passed with `-Jhost` and `-Jport`. The generator takes the output directory as its argument. |
| `scripts/benchmark/` | Provisioning, deployment, run, metadata and analysis scripts for the three JMeter scenarios. `run_main.sh` is the orchestrator and `env.sh` holds every parameter. |
| `scripts/consistency/` | Provisioning, replica set initialisation, scenario runner, inserter, reader and analysis for the two-region replication consistency test. `run_cons.sh` is the orchestrator and `env.sh` holds every parameter. |
| `results/benchmark/` | Per-run statistics for every JMeter run (`per_run.csv`), the aggregated cells (`summary.csv`), error types (`errors.csv`), per-container CPU and memory (`resources.csv`), run timing (`runlog.csv`) and environment metadata (`meta/`). |
| `results/consistency/` | Per-document timestamps for every consistency run (`visible_*.csv`, `insert_*.csv`), chrony offsets before and after each run, the replica set status and RTT measurement (`init_rs.txt`) and the aggregated summary. |

Run 99 in `results/benchmark/per_run.csv` and `visible_*run99.csv` are smoke tests and are excluded from all statistics. Runs 11 to 13 of `replica` / `requests` / `100000` are the isolated write concern w:1 test, and runs 11 to 13 of `standalone` / `users` / `100000` are the isolated driver pool size test.

## Parameters

Nothing in the scripts is tied to a particular project, machine or path. Every value is an environment variable with a default, defined in `scripts/benchmark/env.sh` and `scripts/consistency/env.sh`. `PROJECT_ID` is the only variable without a default and must be set. Examples:

| Variable | Default | Meaning |
| --- | --- | --- |
| `PROJECT_ID` | (required) | GCP project |
| `ZONE`, `ZONE_PRIMARY`, `ZONE_SECONDARY` | `asia-southeast1-b`, `us-central1-a` | Zones of the benchmark VMs and of the two replica set members |
| `MACHINE_APP`, `MACHINE_JMETER`, `MACHINE_TYPE` | `e2-standard-16` | VM machine types |
| `MONGO_IMAGE` | `mongo:7.0.9` (benchmark), `mongo:7.0.0` (consistency) | MongoDB image tag |
| `REPO_ROOT` | top level of the git checkout | Absolute path of this repository. Set it when the scripts are used outside a git checkout |
| `SCRIPT_DIR` | directory of the script being run | Absolute path of the script directory |
| `OUT_DIR` | `$HOME/benchmark_results`, `$HOME/consistency_results` | Where results are collected on the controller |
| `APP_SRC_DIR`, `JMX_SRC_DIR` | `$REPO_ROOT/app`, `$REPO_ROOT/jmeter` | Application code and test plans to deploy |
| `REMOTE_APP_DIR`, `REMOTE_BENCH_DIR`, `REMOTE_JMETER_HOME`, `REMOTE_TMP_DIR` | `/opt/app`, `/opt/bench`, `/opt/jmeter`, `/var/tmp` | Paths on the VMs. `REMOTE_APP_DIR` is written to `.env` as `APP_DIR` for Docker Compose |
| `USERS_LEVELS`, `REQUESTS_LEVELS`, `PAYLOAD_LEVELS`, `PAYLOAD_THREADS` | `100 1000 10000 100000`, `1000 10000 100000 300000`, `0.1kB 1kB 10kB`, `100000` | Scenario levels |
| `RUNS`, `REQUEST_PASSES` | `5`, `3` | Repetitions |
| `NET_IF`, `DELAY_MS`, `VCPUS`, `SCENARIOS` | `ens4`, `1000`, `16`, `baseline delay cpu50 cpu10 cpu1` | Consistency test settings |

## Reproducing

1. Install the Google Cloud SDK, sign in, and create a project with quota for six `e2-standard-16` instances.
2. Clone this repository on a controller machine (a small VM in the same project works well, with `scripts/benchmark/startup_jmeter.sh` as its startup script if it will also act as the JMeter host) and set `REPO_ROOT` to the absolute path of the clone.
3. Run the consistency test: `PROJECT_ID=<id> bash "$REPO_ROOT/scripts/consistency/run_cons.sh"`.
4. Run the benchmark: `PROJECT_ID=<id> bash "$REPO_ROOT/scripts/benchmark/run_main.sh"`. Both are long running, so use `tmux` or `nohup`.
5. `python3 "$REPO_ROOT/scripts/benchmark/50_analyze.py" <OUT_DIR>` and `python3 "$REPO_ROOT/scripts/consistency/06_analyze.py" <OUT_DIR>` produce the CSV files found under `results/`.

The raw JMeter sample logs (`.jtl`, 5.8 GB) are not included and are available from the corresponding author on request.

## License

The application code keeps the license of its origin (based on https://github.com/parsrc/go-mongo-crud-rest-api and https://github.com/minhhungit/mongodb-cluster-docker-compose). Scripts and results are released under the MIT License.
