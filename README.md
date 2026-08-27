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

## Test Devcontainer

This repository includes a basic `.devcontainer/` definition, but it is not the runtime environment for the host control plane. The control-plane commands are still host commands.

The devcontainer exists as a test workspace for devcontainer-specific behaviour being developed here, especially checks such as:

- host-only wrappers refusing to run when `DEVCONTAINER=true`;
- `whereami` reporting a `linux | devcontainer | ...` context;
- authentication diagnostics seeing ordinary in-container tools such as Git, SSH and GitHub CLI.

The test container deliberately stays small. It uses a Microsoft Ubuntu 24.04 devcontainers base image pinned to `linux/amd64`, installs only basic diagnostic tools, sets `DEVCONTAINER=true`, and does not run this repo's host bootstrap.

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

It also links the host tmux configuration to:

```bash
~/.config/tmux/tmux.conf
```

If that file already exists and is not a symlink, bootstrap leaves it alone.

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
- `copilot-cli`
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
tmux attach-session -t <name>
```

If the session does not already exist, `dca` creates a host tmux session with these standard windows:

```text
1 edit      dcssh <name>
2 shell     dcssh <name>
3 git       dcssh <name>
4 docker    host shell
5 ai        dcssh <name>
6 review    dcssh <name>
7 run       dcssh <name>
```

The first version deliberately starts attached shells rather than automatically launching `nvim`, `lazygit`, Copilot or CodeRabbit. That keeps the attach path simple while proving the tmux session/window model.

When `dca` is run from inside an existing tmux session, it uses `tmux switch-client` rather than nesting tmux inside tmux.

### `dcssh`

Attach to a DevPod workspace with host authentication forwarded into the session:

```bash
dcssh neovim-config
```

This wraps:

```bash
devpod ssh --agent-forwarding=true --send-env GH_PROMPT_DISABLED <name>
```

When the host GitHub CLI token is usable by both GitHub CLI and GitHub Copilot CLI, `dcssh` also sends `GH_TOKEN` and `COPILOT_GITHUB_TOKEN`. Supported Copilot token types are GitHub OAuth tokens (`gho_`), GitHub App user tokens (`ghu_`), and fine-grained personal access tokens (`github_pat_`). Classic personal access tokens (`ghp_`) are not forwarded by default because Copilot CLI also reads `GH_TOKEN` and rejects classic PATs.

The command does not run `gh auth login` in the workspace and does not write GitHub credentials into the container image, dotfiles, or repository. If the host has `COPILOT_GITHUB_TOKEN` set to a supported token, that token is forwarded for Copilot. If the host GitHub CLI token is classic and no supported Copilot token is available, the workspace still opens with SSH agent forwarding but GitHub CLI and Copilot CLI do not receive token-based authentication from `dcssh`.

To deliberately forward a classic host GitHub token for GitHub CLI-only work, run:

```bash
DCSSH_FORWARD_CLASSIC_GH_TOKEN=true dcssh neovim-config
```

Use that override only when Copilot CLI is not expected to use the same shell environment.

### `whereami`

Print the compact environment token used by the tmux status bar:

```bash
whereami
```

Typical output:

```text
mac | devpod | neovim-config
wsl | host | ingest
linux | devcontainer | neovim-config
```

In normal project sessions this is called by tmux as:

```bash
whereami <tmux-session-name> <pane-current-path>
```

`dca` marks project sessions with a tmux session option so the status bar can show `devpod` for DevPod-backed sessions even though tmux itself is running on the host. For non-project sessions, the script falls back to the tmux session name, current Git repository basename or current directory basename.

### `dcauth`

Run read-only authentication diagnostics inside a DevPod workspace:

```bash
dcauth neovim-config
```

The check reports:

- basic workspace shell context;
- whether `SSH_AUTH_SOCK` is present;
- Git remotes and `git fetch --dry-run`;
- `ssh-add -l`;
- host GitHub token type and whether it is forwarded as `GH_TOKEN`;
- workspace `gh auth status` when `GH_TOKEN` is present;
- Copilot CLI presence/version and whether `COPILOT_GITHUB_TOKEN` is present and supported;
- CodeRabbit CLI presence/version.

This command is deliberately diagnostic. It does not copy credentials, write tokens, run login flows, or change Git configuration. Use it before and after stopping/starting or deliberately recreating a workspace to see which authentication state survives.

## Tmux

The host tmux configuration lives at `config/tmux/tmux.conf` and is linked by bootstrap.

Key choices:

- Status left shows `platform | location | context`, for example `mac | host | neovim-config`.
- Prefix remains the default `C-b`, matching unconfigured remote tmux hosts.
- Windows and panes start at `1`.
- Mouse mode is off.
- Copy mode uses vi keys.
- `C-b h` and `C-b l` move to previous/next windows.
- `C-b s` opens the session/window tree.
- `C-b p` switches back to the last client.
- `C-b r` reloads `~/.config/tmux/tmux.conf`.

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

Then check authentication propagation:

```bash
dcauth neovim-config
```
