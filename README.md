# AU-100 Machine Report

SKU: AU-100, filed under Technical Reports (TR).

A macOS-focused terminal machine report for login sessions.

This repository is a fork of `usgraphics/usgc-machine-report` and is derived from the original TR-100 script.

## What It Does

`machine_report.sh` prints a compact machine summary in the terminal, including:

- OS, kernel, and full macOS version
- Apple hardware details (model, model ID, chip, cores, memory, serial)
- Host/network details (hostname, machine IP, client IP, interface, DNS, optional public IP)
- System load, disk usage, memory usage, battery
- Optional temperature row (shown only when available)
- VPN status, security status, last login, uptime

## Platform

This AU-100 version is macOS-only.

The script is written for macOS command behavior and data sources (`system_profiler`, `scutil`, `vm_stat`, `pmset`, etc.).

## Installation

Copy the script to your home directory and make it executable:

```bash
cp machine_report.sh ~/.machine_report.sh
chmod +x ~/.machine_report.sh
```

Add it to your interactive shell startup.

### zsh (`~/.zshrc`)

```bash
if [[ -o interactive ]] && [[ -x "$HOME/.machine_report.sh" ]]; then
  "$HOME/.machine_report.sh"
fi
```

### bash (`~/.bashrc`)

```bash
if [[ $- == *i* ]] && [[ -x "$HOME/.machine_report.sh" ]]; then
  "$HOME/.machine_report.sh"
fi
```

Open a new terminal (or source your shell rc file) to run it automatically.

## Configuration

Edit `machine_report.sh` directly.

Key toggles near the top of the file:

- `ENABLE_PUBLIC_IP=0` enables/disables public IP lookup
- `PUBLIC_IP_TIMEOUT=2` sets timeout seconds for public IP request
- `SANITIZE_PII=1` redacts sensitive fields for public-safe output (hostname, IPs, user, serial, DNS, login metadata, VPN IP)

## Attribution

Derived from TR-100 Machine Report by U.S. Graphics, LLC.

Original upstream project:

- https://github.com/usgraphics/usgc-machine-report

## License

BSD 3-Clause License.

Copyright (c) 2024, U.S. Graphics, LLC.

See [`LICENSE`](./LICENSE).
