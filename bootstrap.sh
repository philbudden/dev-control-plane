#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin_dir="${HOME}/bin"
local_bin_dir="${HOME}/.local/bin"
tmux_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/tmux"
tmux_config_file="${tmux_config_dir}/tmux.conf"
dotfiles_repo="${DOTFILES_REPO:-https://github.com/philbudden/dotfiles.git}"
dotfiles_dir="${DOTFILES_DIR:-${HOME}/Developer/dotfiles}"

if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required before running this bootstrap."
    echo "Install Homebrew for this host, then rerun ./bootstrap.sh."
    exit 1
fi

brew_bin_dir="$(brew --prefix)/bin"

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
mkdir -p "${local_bin_dir}"
mkdir -p "${brew_bin_dir}"
mkdir -p "${tmux_config_dir}"

for script in "${repo_dir}"/bin/*; do
    linked_dirs=":"
    for link_dir in "${bin_dir}" "${local_bin_dir}" "${brew_bin_dir}"; do
        case "${linked_dirs}" in
            *":${link_dir}:"*) continue ;;
        esac
        linked_dirs="${linked_dirs}${link_dir}:"

        target="${link_dir}/$(basename "$script")"
        if [ -L "$target" ] || [ ! -e "$target" ]; then
            ln -sfn "$script" "$target"
        else
            echo "Skipping ${target}; a non-symlink file already exists."
        fi
    done
done

if [ -L "${tmux_config_file}" ] || [ ! -e "${tmux_config_file}" ]; then
    ln -sfn "${repo_dir}/config/tmux/tmux.conf" "${tmux_config_file}"
else
    echo "Skipping ${tmux_config_file}; a non-symlink file already exists."
fi

# Ghostty is optional. Link its configuration without requiring the application.
if [ "$(uname -s)" = "Darwin" ]; then
    ghostty_config_dir="${HOME}/Library/Application Support/com.mitchellh.ghostty"
else
    ghostty_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
fi
ghostty_config_file="${ghostty_config_dir}/config.ghostty"
ghostty_source="${repo_dir}/config/ghostty/config.ghostty"
mkdir -p "${ghostty_config_dir}"
if [ -L "${ghostty_config_file}" ]; then
    if [ "$(readlink "${ghostty_config_file}")" = "${ghostty_source}" ]; then
        echo "Ghostty configuration already linked."
    else
        echo "Skipping ${ghostty_config_file}; a different symlink already exists."
    fi
elif [ -f "${ghostty_config_file}" ] && [ ! -s "${ghostty_config_file}" ]; then
    backup="${ghostty_config_file}.empty-backup"
    if [ -e "${backup}" ] || [ -L "${backup}" ]; then
        echo "Skipping ${ghostty_config_file}; backup ${backup} already exists."
    else
        mv "${ghostty_config_file}" "${backup}"
        ln -s "${ghostty_source}" "${ghostty_config_file}"
        echo "Linked Ghostty configuration; preserved empty file at ${backup}."
    fi
elif [ -e "${ghostty_config_file}" ]; then
    echo "Skipping ${ghostty_config_file}; an existing file or directory is in the way."
else
    ln -s "${ghostty_source}" "${ghostty_config_file}"
    echo "Linked Ghostty configuration."
fi

echo "Done. Ensure ${bin_dir}, ${local_bin_dir}, or ${brew_bin_dir} is on PATH."
