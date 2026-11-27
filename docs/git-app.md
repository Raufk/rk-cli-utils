# 🔑 git-app — Git over GitHub App Token

`git-app` enables seamless Git operations (clone, fetch, pull, push, add, commit) authenticated with a short-lived GitHub App installation token.

Tokens are minted on demand, scoped strictly to the targeted repository, held only in memory, and revoked immediately when the command finishes.

---

## 📑 Table of Contents

- [Quick Start](#-quick-start)
- [How It Works](#-how-it-works)
- [Configuration](#-configuration)
  - [Config File (`git-app.conf`)](#config-file-git-appconf)
  - [Environment Variables](#environment-variables)
  - [Configuration Precedence](#configuration-precedence)
  - [Profiles (Multi-App / Multi-Org / Multi-Host)](#profiles-multi-app--multi-org--multi-host)
- [Command Reference](#-command-reference)
  - [Core Git Actions](#core-git-actions)
  - [Validation & Diagnosis (`check`)](#validation--diagnosis-check)
  - [Interactive / Batched Workflows (`session`)](#interactive--batched-workflows-session)
  - [Token Extraction (`token` & `revoke`)](#token-extraction-token--revoke)
  - [Configuration Inspection (`config`)](#configuration-inspection-config)
- [Features in Depth](#-features-in-depth)
  - [Git Options Pass-Through & Restrictions](#git-options-pass-through--restrictions)
  - [Dry Run Mode (`--dry-run`)](#dry-run-mode---dry-run)
  - [Automatic Retry & Rate Limits](#automatic-retry--rate-limits)
  - [Docker BuildKit Integration](#docker-buildkit-integration)
  - [Shell Completion](#shell-completion)
- [Error Handling & Exit Codes](#-error-handling--exit-codes)
- [Security Model](#-security-model)

---

## 🚀 Quick Start

### 1. Set credentials

You can configure credentials using environment variables:

```bash
export GH_APP_ID="6566"
export GH_APP_INSTALLATION_ID="47638"
export GH_APP_PRIVATE_KEY="/secure/path/github-app-private-key.pem"
export GH_HOST="https://github.example.com"
```

Or initialize a persistent config file (created with mode `0600`):

```bash
git-app config init            # opens ~/.config/rk-cli-utils/git-app.conf
git-app config                 # verifies effective settings and origins
```

### 2. Verify access

```bash
git-app check                  # validates credentials, installation and repo access
```

### 3. Run Git operations

```bash
# Clone a repository
git-app clone --depth 1 --branch main https://github.example.com/org/repo.git
cd repo

# Stage, commit, and push
git-app add .
git-app commit "Update configuration"
git-app push origin main

# Pass standard git options
git-app fetch --prune
git-app pull --rebase
git-app push --force-with-lease origin main
```

---

## ⚙️ How It Works

```
┌────────────────────────────────────────────────────────┐
│ 1. Read config & load private key (PEM mode 0600)      │
│ 2. Generate RS256 JWT in memory                        │
│ 3. Authenticate with GitHub API & validate App/install │
│ 4. Request short-lived token scoped to the target repo │
│ 5. Execute git command via GIT_ASKPASS (memory-only)   │
│ 6. Automatically revoke token on command exit          │
└────────────────────────────────────────────────────────┘
```

1. **Local Pre-Flight Checks:** Validates required keys, checks permissions on the private key file, and ensures the remote URL matches `GH_HOST`.
2. **App JWT Generation:** Signs a JSON Web Token with RS256 in memory using OpenSSL.
3. **Repository Installation Validation:** Confirms the installation exists, is active, belongs to the repository owner, and has required permissions.
4. **Token Minting:** Exchanges the JWT for a short-lived GitHub App Installation Token scoped strictly to the target repository (`read` for fetch/clone/pull, `write` for push).
5. **Secure Git Execution:** Passes credentials to Git through a dedicated temporary `GIT_ASKPASS` script in memory. The token is never exposed in process arguments (`ps`), URLs, `.git/config`, or credential helpers.
6. **Automatic Cleanup & Revocation:** Upon process exit (even on failure or signal), the token is immediately revoked via the GitHub API and temporary files are wiped.

---

## 🛠️ Configuration

### Config File (`git-app.conf`)

You can store configuration in `/etc/rk-cli-utils/git-app.conf` or `~/.config/rk-cli-utils/git-app.conf`:

```ini
# Base / default settings
GH_APP_ID=1234
GH_APP_INSTALLATION_ID=5678
GH_APP_PRIVATE_KEY=~/.ssh/my-app.pem
GH_HOST=https://github.example.com
GIT_USER_NAME="Release Bot"
GIT_USER_EMAIL="bot@example.com"
```

Config files:
- Formatted as simple `KEY=VALUE` pairs (parsed, never executed via shell).
- Must have strict permissions (cannot be group- or world-writable).
- Tokens must not be stored in config files.

### Environment Variables

| Variable | Description | Default |
| :--- | :--- | :--- |
| `GH_APP_ID` | GitHub App ID (numeric) | *(Required)* |
| `GH_APP_INSTALLATION_ID` | Installation ID (numeric). Optional for repo-scoped commands: when unset, it is resolved from the repository (`GET /repos/{owner}/{repo}/installation`). **Required** for `--all-repos` | *(Optional)* |
| `GH_APP_PRIVATE_KEY` | Path to unencrypted PEM private key file | *(Required)* |
| `GH_HOST` | Host URL (e.g. `https://github.example.com` or `https://github.com`). Also selects the proxy: `HTTPS_PROXY` if set, otherwise git's `http.<GH_HOST>.proxy` | *(Required)* |
| `GH_API_URL` | API base endpoint *(Optional)* | Auto-detected (`https://api.github.com` for `github.com`, or `$GH_HOST/api/v3` for GHES) |
| `GIT_USER_NAME` | Git author/committer name. **Required** for `commit` and `push` | *(Required for commit/push)* |
| `GIT_USER_EMAIL` | Git author/committer email. **Required** for `commit` and `push` | *(Required for commit/push)* |
| `GIT_APP_PROFILE` | Active profile name | None (uses default section) |
| `GIT_APP_CONFIG` | Path to custom config file | `~/.config/rk-cli-utils/git-app.conf` |
| `GIT_APP_RETRIES` | Max retry attempts for HTTP 429/5xx | `3` |
| `GIT_APP_RETRY_DELAY` | Base retry backoff delay in seconds | `2` |
| `GIT_APP_LOG_LEVEL` | Log verbosity: `error`, `warn`, `info`, `debug` | `info` |
| `GIT_APP_LOG_FILE` | Append redacted logs to this file (mode `0600`) | None |
| `GIT_APP_INSECURE_KEY_PERMS` | Allow non-0600 key permissions (e.g., K8s Secret mounts) | `0` |

### Configuration Precedence

Settings are resolved in the following order (highest precedence wins):

1. **CLI Flags** (`--profile`, `--config`, `--verbose`, `--quiet`, `--dry-run`)
2. **Environment Variables** (`GH_APP_ID`, `GH_APP_PRIVATE_KEY`, etc.)
3. **Active Profile in Config File** (`[profile-name]`)
4. **Default Section in User Config** (`~/.config/rk-cli-utils/git-app.conf`)
5. **Default Section in System Config** (`/etc/rk-cli-utils/git-app.conf`)

### Profiles (Multi-App / Multi-Org / Multi-Host)

You can manage multiple environments or organizations in a single configuration file:

```ini
# Global defaults
GH_APP_PRIVATE_KEY=~/.ssh/default-app.pem
GIT_APP_PROFILE=work

[work]
GH_HOST=https://github.work.example.com
GH_APP_ID=1234
GH_APP_INSTALLATION_ID=5678

[oss]
GH_HOST=https://github.com
# GH_API_URL is auto-detected as https://api.github.com
GH_APP_ID=4321
GH_APP_INSTALLATION_ID=8765
GH_APP_PRIVATE_KEY=~/.ssh/oss-app.pem
```

Switch profiles via `--profile` or `GIT_APP_PROFILE`:

```bash
git-app --profile oss clone https://github.com/my-org/my-project.git
git-app --profile work fetch --prune
```

Inspect profiles:

```bash
git-app config profiles        # list all available profiles
git-app --profile oss config   # inspect effective config for 'oss'
```

---

## 📖 Command Reference

### Core Git Actions

- **`git-app clone [options] <url> [dir]`**
  Clones a repository using a read-scoped token. Supports HTTPS (`https://.../org/repo[.git]`) and SSH (`git@...:org/repo[.git]` or `ssh://...`).
  ```bash
  git-app clone --depth 1 --branch v2.0 https://github.example.com/org/repo.git
  git-app clone git@github.example.com:org/repo.git
  ```

- **`git-app fetch [options] [remote] [refspec]`**
  Fetches updates using a read-scoped token.
  `--all` fetches only remotes whose host matches `GH_HOST`; other remotes are skipped with a warning.
  ```bash
  git-app fetch --prune --tags origin
  git-app fetch --all
  ```

- **`git-app pull [options] [remote] [branch]`**
  Pulls and integrates changes from remote.
  ```bash
  git-app pull --rebase origin main
  ```

- **`git-app push [options] [remote] [branch]`**
  Pushes local changes using a write-scoped token. Verifies the repository is not archived.
  ```bash
  git-app push origin main
  git-app push --force-with-lease origin feature-1
  ```

- **`git-app add <pathspec...>`**
  Stages changes with local git.
  ```bash
  git-app add src/ docs/
  ```

- **`git-app commit [options] <message>`**
  Commits staged changes. `GIT_USER_NAME` and `GIT_USER_EMAIL` are required so every commit is attributed to a known identity; the command fails with exit code 2 if either is missing.
  ```bash
  git-app commit "Release version 1.2.0"
  ```

### Remotes with Embedded Tokens

If a remote URL contains credentials (for example `https://x-access-token:<token>@github.example.com/org/repo.git`), `git-app` ignores the embedded credentials. It uses the cleaned URL and the App token for `fetch`, `pull`, `push`, `ls-remote`, and `clone`. The stored remote configuration is not modified.

### Validation & Diagnosis (`check`)

Validates the full authentication chain against GitHub:
- Reads private key and validates format.
- Generates and signs App JWT.
- Verifies App identity (`/app`).
- Verifies installation status and permissions (`/app/installations/:id`).
- Checks repository accessibility if inside a git directory or given a URL.

```bash
git-app check
git-app check --repo https://github.example.com/org/repo.git
```

### Interactive / Batched Workflows (`session`)

When running multiple Git commands or scripts in sequence, `git-app session` mints **one** token, exports it to the subshell/command, and revokes it once the session exits.

```bash
# Run a batch script or build release
git-app session --write -- make release

# Open an interactive shell with active token
git-app session --write
```

- Nested `git-app` commands automatically detect and reuse the session token without making additional token-minting API requests.
- Validates token expiry and scope before reuse; automatically requests a fresh token if permissions are insufficient.
- Revokes token upon session completion.

### Token Extraction (`token` & `revoke`)

For external tooling (e.g., Docker BuildKit secrets, Go build / private dependency downloading, CI jobs) where a token string is directly required:

```bash
# Mint a token with access to ALL repositories in the GitHub App installation
TOKEN=$(git-app token --all-repos)

# Mint a token strictly scoped to a single repository (Least Privilege)
TOKEN=$(git-app token --repo https://github.example.com/org/repo.git)

# Mint a token with write permissions
TOKEN=$(git-app token --write --all-repos)

# Revoke early when finished
printf '%s' "$TOKEN" | git-app revoke
```

### Configuration Inspection (`config`)

```bash
git-app config                 # show effective configuration with sources
git-app config init            # create/edit ~/.config/rk-cli-utils/git-app.conf
git-app config profiles        # list all profiles in the config file
```

---

## 🔍 Features in Depth

### Git Options Pass-Through & Restrictions

All standard git flags (such as `--depth`, `--branch`, `--tags`, `--prune`, `--rebase`, `--force-with-lease`, `-u`, `-o`) are passed through directly to the underlying `git` binary.

**Security Restrictions:** Options that could leak tokens or invoke arbitrary external binaries are explicitly rejected:
- Flag `--repo` inside standard git commands
- Flags `--upload-pack`, `--receive-pack`, `--exec`
- `clone -c` configurations targeting credential helpers, URL rewrites, or hook scripts

### Dry Run Mode (`--dry-run`)

`--dry-run` validates all local configuration and signs the JWT, but performs **no** network calls and mints **no** tokens. It prints the exact Git command that would be executed.

```bash
git-app --dry-run push origin main
```

For `add` and `commit`, it invokes `git add --dry-run` and `git commit --dry-run`.

### Automatic Retry & Rate Limits

API calls to GitHub handle transient errors with exponential back-off and jitter:
- **Retried:** HTTP 429 (Rate Limit) and HTTP 5xx (Server Errors).
- **Rate-limit Header:** Honored automatically when `Retry-After` is present (including secondary rate limits).
- **Non-retried:** 401 Unauthorized, 403 Forbidden, 404 Not Found, 422 Unprocessable Entity.

Tune retry behavior via `GIT_APP_RETRIES` (default `3`) and `GIT_APP_RETRY_DELAY` (default `2s`, capped at `60s`).

### Docker BuildKit & Go Build Integration

Pass tokens into Docker builds securely without leaking credentials in image layers. Use `--all-repos` to enable downloading multiple private dependencies across your organization:

```bash
# Mint token for all repos in the GitHub App installation
TOKEN=$(git-app token --all-repos) || exit 1

# Build using BuildKit secret
DOCKER_BUILDKIT=1 docker build \
  --secret id=gh_token,env=TOKEN \
  -t my-app:latest .

# Revoke token immediately after build
printf '%s' "$TOKEN" | git-app revoke
```

In your `Dockerfile` (e.g., Go multi-stage build):

```dockerfile
# syntax=docker/dockerfile:1.4
FROM golang:1.22-alpine AS builder
RUN apk add --no-cache git ca-certificates
WORKDIR /app

ENV GOPRIVATE=github.com/my-org/*

COPY go.mod go.sum ./
RUN --mount=type=secret,id=gh_token \
    GH_TOKEN=$(cat /run/secrets/gh_token) && \
    git config --global url."https://x-access-token:${GH_TOKEN}@github.com/".insteadOf "https://github.com/" && \
    go mod download

COPY . .
RUN CGO_ENABLED=0 go build -o /app/server ./cmd/server

FROM alpine:latest
COPY --from=builder /app/server /usr/local/bin/server
CMD ["/usr/local/bin/server"]
```

### Shell Completion

Shell completion for Bash and Zsh is included. It provides autocompletion for commands, options, profiles, remotes, and branch names.

- **Bash:** `source completions/git-app.bash` (or installed system-wide in `/etc/bash_completion.d/`)
- **Zsh:** Add `completions/` to your `fpath` in `~/.zshrc`:
  ```zsh
  fpath=(/path/to/rk-cli-utils/completions $fpath)
  autoload -Uz compinit && compinit
  ```

---

## 🚦 Error Handling & Exit Codes

`git-app` outputs clear error diagnostics pointing directly to the root cause and remediation:

| Exit Code | Classification | Common Causes & Remediation |
| :---: | :--- | :--- |
| `0` | **Success** | Operation completed successfully. |
| `1` | **General Error** | Git command execution failed (e.g. merge conflict, rejected non-fast-forward push). |
| `2` | **Usage / Config Error** | Missing required parameters (`GH_APP_ID`, `GH_APP_PRIVATE_KEY`), invalid private key permissions, insecure flags. |
| `3` | **Network / API Error** | 401 (Invalid App ID or expired JWT / clock skew)<br>403 (Installation suspended / blocked)<br>404 (Repo not installed or wrong installation ID)<br>422 (Insufficient App permissions for action)<br>Network/DNS/TLS timeout. |

---

## 🔒 Security Model

1. **Least Privilege Tokens:** Tokens are minted per-repository with minimal scope (`contents: read` or `contents: write`).
2. **Ephemeral Lifetime:** Tokens are revoked immediately after the command completes or on shell exit.
3. **In-Memory Credential Flow:** Tokens and JWTs never touch disk, environment variable dumps, or shell command lines. Git receives credentials through a secure in-memory `GIT_ASKPASS` descriptor.
4. **Key File Protection:** Private key files are enforced to have `0600` permissions.
5. **Log Redaction:** All tokens are automatically stripped/redacted from `stderr` and log files, even in `--verbose` or `--debug` modes.
6. **Remote URL Validation:** Enforces HTTPS remotes matching `GH_HOST` to prevent accidental credential dispatch to unintended hosts.
7. **Strict API Origin & Redirect Protection:** `GH_API_URL` is strictly validated against `GH_HOST` (must match enterprise host or `api.github.com`), embedded credentials in URLs are blocked, and HTTP redirects are rejected to prevent credential exfiltration.
