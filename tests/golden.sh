#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOCK_DIR="$(mktemp -d)"
ACTUAL_OUT="$(mktemp)"
EXPECTED_OUT="$REPO_ROOT/tests/fixtures/golden-output.txt"

cleanup() {
  rm -rf "$MOCK_DIR" "$ACTUAL_OUT"
}
trap cleanup EXIT

write_mock() {
  local name="$1"
  shift
  cat > "$MOCK_DIR/$name"
  chmod +x "$MOCK_DIR/$name"
}

write_mock system_profiler <<'MOCK'
#!/usr/bin/env bash
cat <<'OUT'
Hardware:

    Hardware Overview:

      Model Name: Mac mini
      Model Identifier: Mac14,13
      Chip: Apple M2
      Total Number of Cores: 8 (4 performance and 4 efficiency)
      Memory: 16 GB
      Serial Number (system): ABCD1234EFGH

Software:

    System Software Overview:

      System Version: macOS 14.5 (23F79)
      Kernel Version: Darwin 23.5.0
      System Integrity Protection: Enabled
      Secure Virtual Memory: Enabled
OUT
MOCK

write_mock whoami <<'MOCK'
#!/usr/bin/env bash
echo "testuser"
MOCK

write_mock hostname <<'MOCK'
#!/usr/bin/env bash
if [[ "${1:-}" == "-f" ]]; then
  echo "test-host.local"
else
  echo "test-host"
fi
MOCK

write_mock ifconfig <<'MOCK'
#!/usr/bin/env bash
cat <<'OUT'
en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
	inet 10.0.0.42 netmask 0xffffff00 broadcast 10.0.0.255
	status: active
lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
	inet 127.0.0.1 netmask 0xff000000
OUT
MOCK

write_mock route <<'MOCK'
#!/usr/bin/env bash
cat <<'OUT'
   route to: default
destination: default
       mask: default
    gateway: 10.0.0.1
  interface: en0
      flags: <UP,GATEWAY,DONE,STATIC,PRCLONING,GLOBAL>
OUT
MOCK

write_mock scutil <<'MOCK'
#!/usr/bin/env bash
cat <<'OUT'
DNS configuration

resolver #1
  nameserver[0] : 1.1.1.1
  nameserver[1] : 9.9.9.9
OUT
MOCK

write_mock uptime <<'MOCK'
#!/usr/bin/env bash
echo "12:00 up 1 day, 2:03, 1 user, load averages: 1.00 0.50 0.25"
MOCK

write_mock vm_stat <<'MOCK'
#!/usr/bin/env bash
cat <<'OUT'
Mach Virtual Memory Statistics: (page size of 4096 bytes)
Pages free:                               100000.
Pages active:                             200000.
Pages inactive:                           150000.
Pages speculative:                         50000.
Pages wired down:                         120000.
Pages occupied by compressor:              30000.
OUT
MOCK

write_mock df <<'MOCK'
#!/usr/bin/env bash
cat <<'OUT'
Filesystem 1024-blocks Used Available Capacity Mounted on
/dev/disk1s1 1000000 250000 750000 25% /
OUT
MOCK

write_mock pmset <<'MOCK'
#!/usr/bin/env bash
cat <<'OUT'
Now drawing from 'Battery Power'
 -InternalBattery-0	95%; discharging; 4:10 remaining present: true
OUT
MOCK

write_mock tailscale <<'MOCK'
#!/usr/bin/env bash
if [[ "${1:-}" == "status" && "${2:-}" == "--json" ]]; then
  echo '{"BackendState":"Running"}'
elif [[ "${1:-}" == "ip" && "${2:-}" == "-4" ]]; then
  echo '100.64.0.1'
fi
MOCK

write_mock last <<'MOCK'
#!/usr/bin/env bash
cat <<'OUT'
testuser   ttys001  203.0.113.4           Wed Apr  8 17:22   still logged in
OUT
MOCK

write_mock who <<'MOCK'
#!/usr/bin/env bash
if [[ "${1:-}" == "am" && "${2:-}" == "i" ]]; then
  echo "testuser console Apr 8 17:22 (203.0.113.4)"
elif [[ "${1:-}" == "-b" ]]; then
  echo "         system boot  Apr  7 10:00"
fi
MOCK

write_mock sw_vers <<'MOCK'
#!/usr/bin/env bash
if [[ "${1:-}" == "-productName" ]]; then
  echo "macOS"
elif [[ "${1:-}" == "-productVersion" ]]; then
  echo "14.5"
fi
MOCK

write_mock getconf <<'MOCK'
#!/usr/bin/env bash
if [[ "${1:-}" == "_NPROCESSORS_ONLN" ]]; then
  echo "8"
fi
MOCK

write_mock uname <<'MOCK'
#!/usr/bin/env bash
if [[ "${1:-}" == "-r" ]]; then
  echo "23.5.0"
fi
MOCK

PATH="$MOCK_DIR:/usr/bin:/bin:/usr/sbin:/sbin" USER="testuser" \
  "$REPO_ROOT/machine_report.sh" > "$ACTUAL_OUT"

if [[ "${1:-}" == "--update" ]]; then
  cp "$ACTUAL_OUT" "$EXPECTED_OUT"
  echo "Updated fixture: $EXPECTED_OUT"
  exit 0
fi

if [[ ! -f "$EXPECTED_OUT" ]]; then
  echo "Missing fixture: $EXPECTED_OUT"
  echo "Run: tests/golden.sh --update"
  exit 1
fi

diff -u "$EXPECTED_OUT" "$ACTUAL_OUT"
echo "golden output OK"
