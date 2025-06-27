# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository containing configuration files for various development tools and shell environments. The repository is designed to be deployed manually or automatically on macOS systems.

## Key Configuration Files

- `.zshrc`: Zsh shell configuration with custom prompt, keybindings, and path settings
- `.vimrc`: Vim editor configuration
- `.tmux.conf`: Tmux terminal multiplexer configuration  
- `.gitconfig`: Git configuration with conditional includes for different environments
- `.gitconfig-work`: Work-specific Git configuration (email: @tsumikiinc.com)
- `.gitconfig-personal`: Personal Git configuration (email: @side2.net)
- `aqua.yaml`: Aqua package manager configuration for managing CLI tools

## Development Environment Setup

### Dependencies

The dotfiles expect the following tools to be available:

- **sheldon**: Plugin manager for Zsh
- **mise**: Runtime version manager (formerly rtx)
- **aqua**: Declarative CLI version manager
- **direnv**: Environment variable manager (macOS)
- **brew**: Package manager (macOS)

### Deployment

Two deployment methods are supported:

1. **Automated (macOS)**: Use the setup script at <https://github.com/karia/setup-mac>
2. **Manual**: Clone the repository and create symlinks:

   ```bash
   cd ~
   git clone git@github.com:karia/dot-files.git
   ln -s ~/dot-files/.* .
   ```

### Git Configuration

The repository uses Git's `includeIf` feature to automatically apply different configurations based on the repository location:

- Repositories under `~/projects/tsumikiinc/` will use work email (@tsumikiinc.com)
- All other repositories will use personal email (@side2.net) by default

After cloning, create symlinks for the Git config files:

```bash
ln -sf ~/dot-files/.gitconfig-work ~/.gitconfig-work
ln -sf ~/dot-files/.gitconfig-personal ~/.gitconfig-personal
```

## Architecture Notes

### Shell Environment

- Uses Zsh with optional Powerlevel10k prompt
- Configures extensive keybindings and auto-completion
- Sets up history sharing across terminal sessions
- Integrates with various development tools (tmuxinator, direnv, mise)

### Path Management

- Adds custom binary paths for local installations
- Configures paths for:
  - Google Cloud SDK
  - Go development ($GOPATH)
  - Aqua-managed tools
  - Linuxbrew (Linux)
  - Snap packages (Linux)
  - npm global packages

### Platform-Specific Configuration

- Contains macOS-specific configurations for MySQL 8.0 and GNU sed
- Supports both macOS and Linux environments

## Common Commands

Since this is a dotfiles repository, there are no build or test commands. The repository is deployed by creating symlinks to the configuration files in the user's home directory.
