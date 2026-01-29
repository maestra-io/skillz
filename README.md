# Maestra Skills Collection

Collection of Cursor/Claude Code skills for automation and DevOps workflows at Maestra.

## 📚 Available Skills

### [connect-postgres-dbeaver](./connect-postgres-dbeaver/)

Automate PostgreSQL database connections through DBeaver using Teleport and Vault.

**Features:**
- 🔍 Automatic database discovery in Teleport
- 🌐 VNet management
- 🔑 Vault credential retrieval
- 🚀 DBeaver launch with saved passwords
- ✅ Zero manual password entry

**Usage:**
```bash
"Подключись к базе nexus"
"Connect to nexus with write access"
```

Or via CLI:
```bash
./connect-postgres-dbeaver/scripts/connect.sh nexus [reader|writer|owner]
```

[→ Full Documentation](./connect-postgres-dbeaver/README.md) | [→ Quick Start](./connect-postgres-dbeaver/QUICKSTART.md)

---

## 🚀 Installation

### For Project (Team-wide)

Clone into your project's `.cursor/skills/` directory:

```bash
cd your-project/.cursor/skills/
git clone https://github.com/maestra-io/skillz.git
```

### For Personal Use

Clone into your global skills directory:

```bash
# Cursor
cd ~/.cursor/skills/
git clone https://github.com/maestra-io/skillz.git

# Claude Code
cd ~/path-to-your-skills/
git clone https://github.com/maestra-io/skillz.git
```

### Using Specific Skills

Each skill is self-contained in its own directory. You can:

1. **Use all skills** - clone the entire repo
2. **Use specific skill** - copy just the skill folder you need
3. **Symlink** - create symlinks to specific skills

```bash
# Example: Use only connect-postgres-dbeaver
cd .cursor/skills/
cp -r skillz/connect-postgres-dbeaver ./
```

## 📖 How Skills Work

Skills are discovered automatically by Cursor/Claude Code when:
- Located in `.cursor/skills/` (project-level)
- Located in `~/.cursor/skills/` (user-level)
- Each skill has a `SKILL.md` file with proper frontmatter

The AI will automatically use the appropriate skill when you ask questions or request tasks that match the skill's description.

## 🛠 Creating New Skills

Want to add a new skill to this collection?

1. Create a new directory: `your-skill-name/`
2. Add `SKILL.md` with frontmatter and instructions
3. Add supporting scripts in `scripts/` if needed
4. Document usage in `README.md`
5. Submit a PR!

See [connect-postgres-dbeaver](./connect-postgres-dbeaver/) as a reference implementation.

## 🔄 Updating Skills

Pull latest changes:

```bash
cd .cursor/skills/skillz
git pull origin main
```

## 📋 Skill Structure

Each skill follows this structure:

```
skill-name/
├── SKILL.md              # AI instructions (required)
├── README.md             # Human documentation
├── QUICKSTART.md         # Quick start guide (optional)
├── CHANGELOG.md          # Version history (optional)
├── examples.md           # Usage examples (optional)
└── scripts/              # Utility scripts (optional)
    ├── main.sh
    └── helper.sh
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add or improve a skill
4. Test thoroughly
5. Submit a pull request

## 📜 License

Internal use for Maestra.io organization.

## 💬 Support

- Create an issue in this repo
- Ask in #platform-team channel
- Contact DevOps team

---

**More skills coming soon!** 🎯
