#!/usr/bin/env bash
set -euo pipefail
umask 077

(($# == 2)) || { printf 'usage: stata-license-helper UID GID\n' >&2; exit 2; }
[[ "$1" =~ ^[0-9]+$ && "$2" =~ ^[0-9]+$ ]] || { printf 'invalid numeric owner\n' >&2; exit 2; }
[[ -d /license-output ]] || { printf 'license output directory is missing\n' >&2; exit 1; }

cd /usr/local/stata
./stinit
[[ -s stata.lic ]] || { printf 'Stata did not create stata.lic\n' >&2; exit 1; }
install -m 0600 -o "$1" -g "$2" stata.lic /license-output/stata.lic
