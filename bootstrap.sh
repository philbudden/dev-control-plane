#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin_dir="${HOME}/bin"
dotfiles_repo="${DOTFILES_REPO:-https://github.com/philbudden/dotfiles.git}"
dotfiles_dir="${DOTFILES_DIR:-${HOME}/Developer/dotfiles}"

if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required before running this bootstrap."
    echo "Install Homebrew for this host, then rerun ./bootstrap.sh."
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "git is required before running this bootstrap."
    exit 1
fi

if [ ! -d "${dotfiles_dir}" ]; then
    mkdir -p "$(dirname "${dotfiles_dir}")"
    echo "Cloning dotfiles into ${dotfiles_dir}..."
    git clone "${dotfiles_repo}" "${dotfiles_dir}"
elif [ -d "${dotfiles_dir}/.git" ]; then
    current_remote="$(git -C "${dotfiles_dir}" remote get-url origin 2>/dev/null || true)"
    if [ "${current_remote}" = "${dotfiles_repo}" ]; then
        echo "Updating dotfiles..."
        git -C "${dotfiles_dir}" pull --ff-only
    else
        echo "Using existing dotfiles at ${dotfiles_dir} with origin: ${current_remote}"
    fi
else
    echo "Using existing dotfiles directory at ${dotfiles_dir}"
fi

echo "Applying shared dotfiles baseline..."
"${dotfiles_dir}/bootstrap.sh"

echo "Installing host-only control-plane tools from Brewfile..."
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
