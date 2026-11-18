#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y openjdk-17-jre-headless chrony python3 curl unzip
# JMETER_VERSION, JMETER_HOME dan BENCH_DIR disisipkan oleh 10_provision.sh; nilai di bawah hanya cadangan.
JMETER_VERSION="${JMETER_VERSION:-5.6.3}"; JMETER_HOME="${JMETER_HOME:-/opt/jmeter}"; BENCH_DIR="${BENCH_DIR:-/opt/bench}"
INSTALL_DIR="$(dirname "$JMETER_HOME")"; mkdir -p "$INSTALL_DIR"
curl -fsSL -o "$INSTALL_DIR/jm.tgz" "https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-${JMETER_VERSION}.tgz" && tar xzf "$INSTALL_DIR/jm.tgz" -C "$INSTALL_DIR" && ln -sfn "$INSTALL_DIR/apache-jmeter-${JMETER_VERSION}" "$JMETER_HOME" && rm "$INSTALL_DIR/jm.tgz"
cat >> "$JMETER_HOME/bin/user.properties" <<'P'
jmeter.save.saveservice.output_format=csv
jmeter.save.saveservice.timestamp_format=ms
jmeter.save.saveservice.time=true
jmeter.save.saveservice.label=true
jmeter.save.saveservice.response_code=true
jmeter.save.saveservice.response_message=true
jmeter.save.saveservice.thread_name=true
jmeter.save.saveservice.successful=true
jmeter.save.saveservice.bytes=true
jmeter.save.saveservice.sent_bytes=false
jmeter.save.saveservice.latency=true
jmeter.save.saveservice.connect_time=true
jmeter.save.saveservice.data_type=false
jmeter.save.saveservice.assertion_results_failure_message=false
jmeter.save.saveservice.url=false
jmeter.save.saveservice.hostname=false
jmeter.save.saveservice.thread_counts=false
jmeter.save.saveservice.idle_time=false
jmeter.save.saveservice.encoding=false
jmeter.save.saveservice.print_field_names=true
summariser.interval=30
P
# hanya yang diperlukan agar 100.000 thread dapat dibuat; pengaturan jaringan dibiarkan default
cat > /etc/sysctl.d/90-jmeter.conf <<'S'
vm.max_map_count=2000000
kernel.threads-max=2000000
kernel.pid_max=4194304
S
sysctl --system >/dev/null
cat > /etc/security/limits.d/90-jmeter.conf <<'L'
* soft nofile 1048576
* hard nofile 1048576
* soft nproc  unlimited
* hard nproc  unlimited
L
mkdir -p "$BENCH_DIR" && chmod 777 "$BENCH_DIR"
touch "${TMP_DIR:-/var/tmp}/setup_done"
