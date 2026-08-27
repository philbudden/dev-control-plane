#!/usr/bin/env bash
set -euo pipefail

printf "dev-control-plane test devcontainer ready\n"
printf "This container is for testing devcontainer-specific behaviour, not for running the host control plane.\n"
printf "Useful checks:\n"
printf "  bin/whereami\n"
printf "  bin/dcu\n"
printf "  bin/dca example-workspace\n"
printf "  bin/dcr example-workspace\n"
printf "  bin/dcauth example-workspace\n"
