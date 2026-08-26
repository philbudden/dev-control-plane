# Dev Control Plane

Terminal-only host control-plane setup for the terminal-native development workflow.

This repository is intentionally separate from the dotfiles repo. It prepares the host-side tools and commands used to create, start, attach to, and deliberately recreate development containers. Homebrew is a prerequisite and is not installed by this repo.

## Scope

This repo manages:

- The existing `~/Developer/dotfiles` baseline on the host.
- Host-only terminal tools through Homebrew.
- Small host-side wrapper commands for DevPod CLI workflows.
- The control-plane layer for `terminal -> tmux -> devcontainer -> Neovim`.

This repo does not manage:

- GUI applications such as Ghostty.
- DevPod GUI.
- Host shell dotfiles directly; those remain owned by `~/Developer/dotfiles`.
- Neovim configuration.
- SSH private keys.
- Docker Desktop, OrbStack, Docker Engine, or WSL provisioning.
- Project-specific devcontainer definitions.

## Prerequisites

Install these on the host before using this repo:

- Homebrew, used by `bootstrap.sh` to install the cross-platform terminal tool baseline.
- Docker, Docker Desktop, OrbStack, or another Docker-compatible runtime supported by DevPod CLI.
- DevPod CLI, installed from the official CLI-only install path rather than the DevPod GUI cask.

This repo does not install these prerequisites. It also does not configure Rosetta 2 or x86 container support in virtualised environments.

## Bootstrap

```bash
git clone https://github.com/philbudden/dev-control-plane.git ~/Developer/dev-control-plane
cd ~/Developer/dev-control-plane
./bootstrap.sh
```

`bootstrap.sh` expects Homebrew to already be installed. It first clones or updates `~/Developer/dotfiles` and runs:

```bash
~/Developer/dotfiles/bootstrap.sh
```

That applies the shared CLI, shell, Git, Starship and Neovim baseline from the same repo used inside devcontainers.

Then it runs this repo's host-only package layer:

```bash
brew bundle --file Brewfile
```

Then it links scripts from `bin/` into `~/bin` when there is no existing non-symlink file in the way.

DevPod CLI is also required for the wrapper commands, but it is not installed by this bootstrap. The current Homebrew `devpod` package is a cask for the DevPod UI app, so this repo deliberately avoids it. Install the CLI-only DevPod binary using the official DevPod CLI install instructions, then use this repo for the rest of the host terminal control plane.

The dotfiles location can be overridden when testing:

```bash
DOTFILES_DIR=~/Developer/dotfiles ./bootstrap.sh
```

The dotfiles source can also be overridden:

```bash
DOTFILES_REPO=https://github.com/example/dotfiles.git ./bootstrap.sh
```

## Shared Packages From Dotfiles

The shared baseline is installed from `~/Developer/dotfiles/Brewfile`. It includes tools such as:

- `bat`
- `fd`
- `fzf`
- `gh`
- `jq`
- `lazygit`
- `neovim`
- `ripgrep`
- `starship`
- `stow`
- `unzip`
- `zip`
- `zoxide`

Add shared CLI tools there, not here, so the host and devcontainer baselines do not drift.

## Host-Only Packages

This repo's `Brewfile` should contain only tools that make sense on the host/control plane but not in every devcontainer. The current host-only package is:

- `lazydocker`
- `tmux`

Host `tmux` is part of the host control-plane requirement because project sessions live on the host side of the DevPod attach workflow. It is deliberately not installed by the devcontainer dotfiles baseline.

DevPod CLI is intentionally absent from the Homebrew baseline until there is a CLI-only Homebrew package. Do not replace it with the DevPod GUI cask.

## Commands

### `dcu`

Create or start a DevPod workspace for the current directory:

```bash
dcu
```

Use an explicit workspace name:

```bash
dcu neovim-config
```

This runs:

```bash
devpod up . --id <name> --ide none
```

### `dca`

Attach to a DevPod workspace inside a tmux session with the same name:

```bash
dca neovim-config
```

This runs:

```bash
tmux new-session -A -s <name> "devpod ssh <name>"
```

### `dcr`

Deliberately recreate a DevPod workspace:

```bash
dcr neovim-config
```

This runs:

```bash
devpod up <name> --recreate --ide none
```

Use this only when the devcontainer definition has changed or the workspace state is broken.

## Verification

After bootstrap, verify the host control-plane tools:

```bash
devpod version
tmux -V
lazydocker --version
gh --version
rg --version
fd --version
bat --version
zoxide --version
```

Then test the first workflow against a small project:

```bash
cd ~/Developer/neovim-config
dcu neovim-config
dca neovim-config
```

Inside the attached workspace, confirm the devcontainer dotfiles bootstrap has provided the inner environment.
