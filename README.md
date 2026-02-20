# Skillz

AI skills for Maestra/Mindbox platform automation.

## Installation

Clone the repo:

```bash
git clone git@github.com:maestra-io/skillz.git
```

Symlink the skills you need:

```bash
# Claude Code
ln -s ~/skillz/connect-postgres-dbeaver ~/.claude/skills/connect-postgres-dbeaver

# Claude Code agents
ln -s ~/skillz/search-code ~/.agents/skills/search-code
```

Or use npx:

```bash
npx maestra-skills install connect-postgres-dbeaver
```

## Available Skills

- **connect-postgres-dbeaver** — Automate PostgreSQL connections through DBeaver using Teleport and Vault. Zero manual password entry.
- **linqpad-connection** — Create or refresh LINQPad database connections using Vault credentials.
- **search-code** — Search code across Mindbox/Maestra repositories spanning GitLab and GitHub.
- **vault-helpers** — Get database credentials from Vault, login, switch environments, copy creds to clipboard.

## Need something else?

If you lack a skill or want to request one, check the [How do I](https://www.notion.so/How-do-I-30ce08805078806b8de3f45e66b1a1e8) page.
