#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin_dir="${HOME}/bin"

if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required before running this bootstrap."
    echo "Install Homebrew for this host, then rerun ./bootstrap.sh."
    exit 1
fi

echo "Installing host control-plane tools from Brewfile..."
brew bundle --file "${repo_dir}/Brewfile"

if ! command -v devpod >/dev/null 2>&1; then
    echo "DevPod CLI is required for dcu/dca/dcr but is not installed."
    echo "Install the CLI-only DevPod binary from the official DevPod install docs, then rerun or use the wrapper commands."
fi

mkdir -p "${bin_dir}"

for script in "${repo_dir}"/bin/*; do
    target="${bin_dir}/$(basename "$script")"
    if [ -L "$target" ] || [ ! -e "$target" ]; then
        ln -sfn "$script" "$target"
    else
        echo "Skipping ${target}; a non-symlink file already exists."
    fi
done

echo "Done. Ensure ${bin_dir} is on PATH."
