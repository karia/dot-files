# Codex configuration

The home directory's `~/.codex` path is a symlink to this directory. Only files
that describe intentional, portable preferences belong in Git.

## Tracked files

- `config.toml` contains stable user preferences.
- `.gitignore` keeps Codex runtime state out of the repository.

Codex can append machine-local state to `config.toml`, including trusted project
paths, hook approval hashes, and dismissed first-run notices. Do not commit those
generated sections.

User-authored skills are stored under `.claude/skills` and exposed to Codex
through the repository's `$HOME/.agents/skills` symlink. Codex supports this
user-level skill location and follows symlinked skill directories.

## Ignored files

All other files under this directory are ignored. This includes credentials,
session transcripts, histories, memories, SQLite databases, logs, caches,
generated shell snapshots, locks, temporary files, installed plugins, bundled
system skills, and integration-generated files.

In particular, `auth.json` contains access tokens and must never be committed.
Use `codex login` to authenticate each machine independently.
