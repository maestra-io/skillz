---
name: search-code
description: Search code across Mindbox/Maestra repositories spanning GitLab and GitHub. Use when the user asks to find code, grep across repos, locate which repo contains something, find usages of a function/class/config across the codebase, or invokes /search-code. Also auto-trigger when the user asks questions like "where is X used", "which repo has Y", "find all Dockerfiles with Z".
---

# Search Code

Search across ~800+ Mindbox/Maestra repositories hosted on GitLab and GitHub.

## Repo Organization

- **GitLab (source of truth):** `mindbox.gitlab.yandexcloud.net/development` — most repos live here
- **GitHub (mirror + some originals):** `github.com/maestra-io` — ~800 repos mirrored from GitLab, plus GitHub-only repos
- **GitHub-only repos** tend to involve: Leaseweb, Shopify, Maestra-specific tooling
- **Override repos** (exist on both, prefer GitHub version): `dns`, `iam`

## Search Strategy

### 1. Start with GitHub (`gh search code`)

GitHub has superior code search. Search here first:

```bash
gh search code --owner maestra-io "SEARCH_TERM"
```

Useful flags:
- `--language go` — filter by language
- `--filename Dockerfile` — search specific filenames
- `--match path` or `--match file` — match against path/filename instead of content
- `-L 50` — increase result limit (default 30)

Examples:
```bash
# Find usage of a function across repos
gh search code --owner maestra-io "getMaestraServiceForShop"

# Find all repos with a specific Dockerfile base image
gh search code --owner maestra-io --filename Dockerfile "node:20"

# Find Helm values files referencing a service
gh search code --owner maestra-io --filename values.yaml "serviceMonitor"

# Search in a specific repo
gh search code --repo maestra-io/shopify-app "earnPoints"
```

### 2. Fall back to GitLab (`glab api`)

For repos not mirrored to GitHub, or when you need to search GitLab specifically:

```bash
# Search code within a specific project (project ID or URL-encoded path)
glab api "projects/development%2FREPO_NAME/search?scope=blobs&search=TERM" --hostname mindbox.gitlab.yandexcloud.net

# Search across all projects in the development group (group ID needed)
glab api "groups/GROUPID/search?scope=blobs&search=TERM" --hostname mindbox.gitlab.yandexcloud.net

# List projects to find one
glab api "groups/GROUPID/projects?search=REPO_NAME&per_page=20" --hostname mindbox.gitlab.yandexcloud.net
```

If you don't know the group ID, look it up first:
```bash
glab api "groups?search=development" --hostname mindbox.gitlab.yandexcloud.net
```

### 3. Local search (when repos are cloned)

If the user has repos cloned locally, use Grep tool directly for fast local search.

## Source of Truth Rules

When presenting results, always determine the correct source of truth:

| Condition | Source of truth |
|-----------|----------------|
| Repo exists only on GitHub | GitHub (maestra-io) |
| Repo is `dns` or `iam` | GitHub (maestra-io) — these override GitLab |
| Repo exists on both (default) | **GitLab** is source of truth, GitHub is read-only mirror |
| Repo exists only on GitLab | GitLab |

## Output Rules

**CRITICAL:** After presenting search results, ALWAYS include a source-of-truth note for each repo found:

- For mirrored repos (the majority): append a note like:
  > To modify this code, use the GitLab repo at `mindbox.gitlab.yandexcloud.net/development/REPO_NAME` — the GitHub copy is a read-only mirror.

- For GitHub-only or override repos (`dns`, `iam`, Shopify/Leaseweb/Maestra-specific):
  > This repo lives on GitHub (maestra-io/REPO_NAME) as its source of truth.

**Never let the user accidentally clone/edit the read-only GitHub mirror when GitLab is the source of truth.**

## Deduplication

If searching both GitHub and GitLab, deduplicate results by repo name. Prefer showing the GitHub search result (better formatting) but annotate with the correct source of truth per the rules above.
