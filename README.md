<div align="center">

# 🚀 rk-cli-utils

### _Supercharge Your DevOps Workflow_ ⚡

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0-blue.svg)](https://github.com/Raufk/rk-cli-utils/releases)
[![Platform](https://img.shields.io/badge/platform-Linux-lightgrey.svg)](https://www.linux.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![RHEL](https://img.shields.io/badge/RHEL-EE0000?logo=redhat&logoColor=white)](https://www.redhat.com/)
[![Shell](https://img.shields.io/badge/shell-bash-green.svg)](https://www.gnu.org/software/bash/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

_A collection of lightweight CLI utilities designed to simplify everyday DevOps and developer workflows, boosting productivity and ensuring consistency across your team._

[Features](#-features) • [Installation](#-installation) • [Usage](#-usage) • [Documentation](#-documentation) • [Contributing](#-contributing)

</div>

---

## 🎯 Why rk-cli-utils?

<table>
<tr>
<td width="33%" align="center">
<img src="https://raw.githubusercontent.com/github/explore/80688e429a7d4ef2fca1e82350fe8e3517d3494d/topics/terminal/terminal.png" width="80" height="80" />
<h3>🎨 Simple & Elegant</h3>
<p>Clean, intuitive commands that just work</p>
</td>
<td width="33%" align="center">
<img src="https://raw.githubusercontent.com/github/explore/80688e429a7d4ef2fca1e82350fe8e3517d3494d/topics/bash/bash.png" width="80" height="80" />
<h3>⚡ Lightning Fast</h3>
<p>Pure bash implementation with zero overhead</p>
</td>
<td width="33%" align="center">
<img src="https://raw.githubusercontent.com/github/explore/80688e429a7d4ef2fca1e82350fe8e3517d3494d/topics/git/git.png" width="80" height="80" />
<h3>🔧 DevOps Ready</h3>
<p>Built for modern CI/CD pipelines</p>
</td>
</tr>
</table>

---

## ✨ Features

### 🔐 SSH Setup Made Easy

> Configure Git and SSH keys in seconds, not minutes

```bash
# One command to rule them all
setup-ssh --email dev@company.com --user "John Doe" --key-file ~/.ssh/id_rsa
```

**What it does:**

- ✅ Configures Git user credentials globally
- ✅ Sets up SSH keys for GitHub/GitHub Enterprise
- ✅ Automatically rewrites HTTPS URLs to SSH
- ✅ Adds hosts to known_hosts securely
- ✅ Supports custom Git hosting platforms

---

### 💬 Slack Integration

> Send beautiful, color-coded messages to multiple channels instantly

```bash
# Notify your team with style
slack-send --token xoxb-your-token \
           --channel "#deployments,#alerts" \
           --message "🚀 Production deployment successful!" \
           --color good
```

**Capabilities:**

- 📢 Multi-channel broadcasting
- 🎨 Color-coded messages (good/warning/danger/custom hex)
- 📝 Message sections with `~` delimiter
- 🔍 User lookup by email
- ⚡ Async delivery with error handling

---

### 🔍 Slack User Lookup

> Find Slack user IDs from email addresses effortlessly

```bash
get-slack-id --email user@company.com --token xoxb-your-token
```

---

### 🔑 Git over GitHub App Token

> Clone, commit, fetch, pull and push using a short-lived GitHub App installation token

```bash
export GH_APP_ID="6566"
export GH_INSTALLATION_ID="47638"
export GH_PRIVATE_KEY="/secure/path/github-app-private-key.pem"
export GH_HOST="https://github.example.com"

# Configure once (file is created with mode 600), or use environment variables
git-app config init            # edit ~/.config/rk-cli-utils/git-app.conf
git-app config                 # show effective settings and where each came from

git-app check                  # validate credentials, installation and repo access
git-app clone --depth 1 --branch main https://github.example.com/org/repo.git
cd repo
git-app add .
git-app commit "Update configuration"
git-app push --force-with-lease origin main
git-app --dry-run push origin main       # show what would happen, no network
git-app --profile oss fetch --prune      # use another host/app/org
git-app session --write -- make release  # one token for a whole workflow
TOKEN=$(git-app token --repo https://github.example.com/org/repo.git)   # token only, for docker build etc.
```

**Git options pass through.** Anything git accepts after `clone`, `fetch`, `pull` or `push`
(`--depth`, `--branch`, `--prune`, `--tags`, `--rebase`, `--force-with-lease`, `-u`, `-o`, ...) is
forwarded unchanged. `push` with no branch pushes the current one (not with `--tags`/`--all`/`--mirror`);
`push --delete` needs an explicit branch. Options that could send the token elsewhere or run a program
(`--repo`, `--upload-pack`, `--receive-pack`, `--exec`, and `clone -c` for credential/url/hook keys) are refused.

**Dry run.** `--dry-run` runs the local checks (config, key, JWT signing), makes **no** network
request and mints **no** token, then prints what it would verify and the exact git command it would run.
`add`/`commit` become `git add --dry-run`/`git commit --dry-run`.

**Retry.** HTTP 429 and 5xx from the GitHub API are retried with exponential back-off and jitter
(`GIT_APP_RETRIES`, default 3; `GIT_APP_RETRY_DELAY`, default 2s, capped at 60s). `Retry-After` is honoured,
including on a 403 secondary rate limit. Authentication and permission errors (401/403/404/422) are never retried.
The `git` transfer itself is not retried.

**Token reuse.** Each command normally mints and revokes its own token. `git-app session` mints
**one** token, runs your command (or an interactive shell) with it, and revokes it when that exits;
`git-app` calls inside reuse it, without further API calls. The token is only reused for the same host and repository,
if it has enough permission (`--write` for push) and is not close to expiring; otherwise a separate token is requested.
Nothing is written to disk.

**Token only (`git-app token`).** Prints just the installation token on stdout (logs go to stderr), for tools
that run longer than one command, such as `docker build`. It is scoped to one repository (`--write` for push) and is
**not revoked**: it stays valid until it expires (1 hour). Revoke early with `git-app revoke`
(reads `$GH_APP_TOKEN` or stdin).

```bash
TOKEN=$(git-app token --repo https://github.example.com/org/repo.git) || exit 1
DOCKER_BUILDKIT=1 docker build --secret id=gh_token,env=TOKEN -t myimage .   # RUN --mount=type=secret,id=gh_token
printf '%s' "$TOKEN" | git-app revoke                                       # when done
```

Treat the output as a credential: prefer a BuildKit secret over `--build-arg` (build args are stored in the image
history), and never write it to a file in the repo or a log.

**Profiles.** Keep several hosts, Apps or organisations in one config file:

```ini
GH_PRIVATE_KEY=~/.ssh/default-app.pem   # defaults, before any [section]
GIT_APP_PROFILE=work                    # profile used when none is given

[work]
GH_HOST=https://github.work.example.com
GH_APP_ID=1234
GH_INSTALLATION_ID=5678

[oss]
GH_HOST=https://github.com
GH_API_URL=https://api.github.com
GH_APP_ID=4321
GH_INSTALLATION_ID=8765
GH_PRIVATE_KEY=~/.ssh/oss-app.pem
```

Pick one with `--profile <name>` or `GIT_APP_PROFILE`; a profile overrides the defaults and environment
variables override both. `git-app config` shows the effective values and where each came from;
`git-app config profiles` lists the names.

**Shell completion** (bash and zsh) for commands, options, profiles, remotes and branches is installed by the
RPM/DEB. From a checkout: `source completions/git-app.bash`, or put `completions/` on your zsh `fpath`.

| Setting              | Purpose                                              |
| -------------------- | ---------------------------------------------------- |
| `GH_APP_ID`          | GitHub App ID                                        |
| `GH_INSTALLATION_ID` | Installation ID (numeric)                            |
| `GH_PRIVATE_KEY`     | Path to the App's unencrypted PEM key                |
| `GH_HOST`            | e.g. `https://github.example.com`                    |
| `GH_API_URL`         | Optional, default `$GH_HOST/api/v3`                  |
| `GIT_USER_NAME` / `GIT_USER_EMAIL` | Local commit identity (both or neither) |
| `GIT_APP_PROFILE`    | Profile to use (same as `--profile`)                 |
| `GIT_APP_RETRIES` / `GIT_APP_RETRY_DELAY` | Retry count (3) and base back-off seconds (2) |
| `GIT_APP_LOG_LEVEL`  | `error`, `warn`, `info` (default), `debug`           |
| `GIT_APP_LOG_FILE`   | Also append redacted logs to this file (mode 600)    |

Configuration sources, lowest to highest precedence: `/etc/rk-cli-utils/git-app.conf`,
`~/.config/rk-cli-utils/git-app.conf`, `$GIT_APP_CONFIG` or `--config <file>`, then environment variables.
Config files are parsed as `KEY=VALUE` (never executed), must not be group/world-writable, and may not contain tokens.

**Validation before every operation:** configuration and key checks, App JWT, installation
(exists, not suspended, owned by the repository owner), token scope, repository access
(and not archived/read-only for push).

**Errors** name the cause and a fix (401 bad App ID/key/clock, 403 suspended/blocked, 404 wrong
installation or repo not installed, 422 missing permission, network/DNS/TLS problems).
Exit codes: `0` ok, `1` error, `2` usage/configuration, `3` network/API.

**Security**

- Private key must be a regular, readable, unencrypted PEM with mode `600` (override for read-only secret mounts: `GIT_APP_INSECURE_KEY_PERMS=1`)
- Token is scoped to the single repository, `contents: read` (or `write` for push)
- Token and JWT live in memory only; they reach curl via stdin and git via `GIT_ASKPASS`, never on a command line, in a URL, git config or credential store
- Token is revoked when the command exits; temp files are mode 700 and removed
- Logs go to stderr, tokens are redacted, `--verbose` still never prints them
- Remotes must be HTTPS and belong to `GH_HOST`

Global options (before the action): `--profile <name>`, `--config <file>`, `--dry-run`, `--verbose`, `--quiet`, `-h/--help`, `-V/--version`.

---

## 📦 Installation

### 🚀 Quick Install (Auto-detect OS)

The installation script automatically detects your Linux distribution and installs the appropriate package:

```bash
curl -fsSL https://raw.githubusercontent.com/Raufk/rk-cli-utils/main/install/install.sh | bash
```

**Supported Platforms:**

- ✅ Ubuntu / Debian (`.deb` package)
- ✅ RHEL / CentOS / Rocky / AlmaLinux (`.rpm` package)

---

### Manual Installation

<details>
<summary><b>📥 Ubuntu/Debian - Download DEB Package</b></summary>

```bash
# Download the latest release
curl -LO https://github.com/Raufk/rk-cli-utils/releases/download/v1.0/rk-cli-utils.deb

# Install
sudo dpkg -i rk-cli-utils.deb

# Verify installation
rk --version
```

</details>

<details>
<summary><b>📥 RHEL/CentOS - Download RPM Package</b></summary>

```bash
# Download and install directly
sudo yum install https://github.com/Raufk/rk-cli-utils/releases/download/v1.0/rk-cli-utils-1.0-1.el9.noarch.rpm

# Or download first, then install
wget https://github.com/Raufk/rk-cli-utils/releases/download/v1.0/rk-cli-utils-1.0-1.el9.noarch.rpm
sudo yum localinstall rk-cli-utils-1.0-1.el9.noarch.rpm

# Verify installation
rk --version
```

</details>

<details>
<summary><b>🔨 Build from Source (Using Makefile)</b></summary>

#### Build Both RPM and DEB Packages

```bash
# Clone the repository
git clone https://github.com/Raufk/rk-cli-utils.git
cd rk-cli-utils

# Build both packages (recommended)
make all

# Packages will be created in:
# - RPM: ~/rpmbuild/RPMS/noarch/rk-cli-utils-*.rpm
# - DEB: build/deb/rk-cli-utils-*.deb
```

#### Build RPM Package Only (RHEL/CentOS/Rocky/AlmaLinux)

```bash
# Build RPM package
./build_package.sh

# or
make rpm

# Install
sudo yum localinstall ~/rpmbuild/RPMS/noarch/rk-cli-utils-*.rpm

# Verify
rk --version
```

#### Build DEB Package Only (Ubuntu/Debian)

```bash
# Build DEB package
make deb

# Install
sudo dpkg -i build/deb/rk-cli-utils-*.deb

# Verify
rk --version
```

#### Clean Build Artifacts

```bash
# Remove all build files
make clean
```

#### Available Make Targets

| Target         | Description                                   |
| -------------- | --------------------------------------------- |
| `make all`     | Build both RPM and DEB packages (default)     |
| `make rpm`     | Build RPM package only                        |
| `make deb`     | Build DEB package only                        |
| `make clean`   | Remove all build artifacts                    |
| `make prepare` | Prepare build environment (version injection) |

</details>

---

## 🚀 Usage

### Command Overview

| Command        | Description         | Example                                                              |
| -------------- | ------------------- | -------------------------------------------------------------------- |
| `setup-ssh`    | Configure SSH & Git | `setup-ssh --email dev@co.com --user "Dev" --key-file ~/.ssh/id_rsa` |
| `slack-send`   | Send Slack messages | `slack-send --token TOKEN --channel "#ops" --message "Hello!"`       |
| `get-slack-id` | Get Slack user ID   | `get-slack-id --email user@co.com --token TOKEN`                     |
| `git-app`      | Git via GitHub App  | `git-app push origin main`                                           |

### 📚 Detailed Examples

<details>
<summary><b>🔐 SSH Setup Examples</b></summary>

#### Basic Setup (GitHub)

```bash
setup-ssh \
  --email developer@company.com \
  --user "Jane Developer" \
  --key-file ~/.ssh/id_rsa
```

#### GitHub Enterprise Setup

```bash
setup-ssh \
  --email dev@company.com \
  --user "Dev Team" \
  --key-file ~/.ssh/ghe_key \
  --host github.enterprise.com
```

#### Using Key Content Directly

```bash
setup-ssh \
  --email dev@company.com \
  --user "CI Bot" \
  --key-file "$(cat /secure/path/to/key)"
```

</details>

<details>
<summary><b>💬 Slack Messaging Examples</b></summary>

#### Success Notification

```bash
slack-send \
  --token xoxb-your-slack-token \
  --channel "#deployments" \
  --message "✅ Production deployment completed successfully!" \
  --color good
```

#### Warning Alert

```bash
slack-send \
  --token xoxb-your-slack-token \
  --channel "#alerts" \
  --message "⚠️ High memory usage detected on server-01" \
  --color warning
```

#### Critical Error

```bash
slack-send \
  --token xoxb-your-slack-token \
  --channel "#incidents,#on-call" \
  --message "🚨 Database connection failed~Check logs immediately" \
  --color danger
```

#### Custom Color

```bash
slack-send \
  --token xoxb-your-slack-token \
  --channel "#general" \
  --message "📊 Weekly report is ready" \
  --color "#36a64f"
```

</details>

<details>
<summary><b>🔍 User Lookup Example</b></summary>

```bash
# Get Slack user ID
SLACK_ID=$(get-slack-id \
  --email john.doe@company.com \
  --token xoxb-your-slack-token)

echo "User ID: $SLACK_ID"
```

</details>

---

## 🏗️ Architecture

```
rk-cli-utils/
├── 📁 bin/
│   └── rk                    # Main CLI dispatcher
├── 📁 lib/
│   ├── ssh.sh               # SSH setup logic
│   ├── git.sh               # GitHub App token git operations
│   └── slack.sh             # Slack API integration
├── 📁 completions/
│   ├── git-app.bash         # bash completion (git-app, rk)
│   └── _git-app             # zsh completion (git-app, rk)
├── 📁 wrappers/
│   ├── setup-ssh            # Direct command wrapper
│   ├── slack-send           # Direct command wrapper
│   ├── git-app              # Direct command wrapper
│   └── get-slack-id         # Direct command wrapper
├── 📁 packaging/
│   └── rk-cli-utils.spec    # RPM package specification
├── 📁 install/
│   └── install.sh           # Installation script
└── build_package.sh         # Build automation
```

---

## 🔧 Requirements

| Dependency        | Purpose           | Installation                  |
| ----------------- | ----------------- | ----------------------------- |
| `bash`            | Shell interpreter | Pre-installed                 |
| `git`             | Version control   | `yum install git`             |
| `curl`            | HTTP client       | `yum install curl`            |
| `jq`              | JSON processor    | `yum install jq`              |
| `openssh-clients` | SSH tools         | `yum install openssh-clients` |
| `openssl`         | JWT signing (`git-app`) | `yum install openssl`   |

---

## 🎓 Documentation

### Environment Variables

```bash
# Optional: Set default Slack token
export SLACK_TOKEN="xoxb-your-token"

# Optional: Set default Git host
export GIT_HOST="github.enterprise.com"
```

### Exit Codes

| Code | Meaning                    |
| ---- | -------------------------- |
| `0`  | Success                    |
| `1`  | General error              |
| `2`  | Missing required parameter |
| `3`  | Network/API error          |

---

## 🤝 Contributing

We love contributions! 💙

<div align="center">

[![Contributors](https://img.shields.io/github/contributors/Raufk/rk-cli-utils?style=for-the-badge)](https://github.com/Raufk/rk-cli-utils/graphs/contributors)
[![Issues](https://img.shields.io/github/issues/Raufk/rk-cli-utils?style=for-the-badge)](https://github.com/Raufk/rk-cli-utils/issues)
[![Pull Requests](https://img.shields.io/github/issues-pr/Raufk/rk-cli-utils?style=for-the-badge)](https://github.com/Raufk/rk-cli-utils/pulls)

</div>

### How to Contribute

1. 🍴 Fork the repository
2. 🌿 Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. ✍️ Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. 📤 Push to the branch (`git push origin feature/AmazingFeature`)
5. 🎉 Open a Pull Request

---

## 📝 License

This project is licensed.

---

## 👨‍💻 Author

<div align="center">

**Rauf K**

[![Email](https://img.shields.io/badge/Email-abdulraufkc111%40gmail.com-red?style=for-the-badge&logo=gmail)](mailto:abdulraufkc111@gmail.com)
[![GitHub](https://img.shields.io/badge/GitHub-Raufk-black?style=for-the-badge&logo=github)](https://github.com/Raufk)

</div>

---

## 🌟 Show Your Support

If this project helped you, please consider giving it a ⭐️!

<div align="center">

[![Star History Chart](https://api.star-history.com/svg?repos=Raufk/rk-cli-utils&type=Date)](https://star-history.com/#Raufk/rk-cli-utils&Date)

</div>

---

## 📊 Project Stats

<div align="center">

![GitHub repo size](https://img.shields.io/github/repo-size/Raufk/rk-cli-utils?style=for-the-badge)
![GitHub code size](https://img.shields.io/github/languages/code-size/Raufk/rk-cli-utils?style=for-the-badge)
![Lines of code](https://img.shields.io/tokei/lines/github/Raufk/rk-cli-utils?style=for-the-badge)

</div>

---

<div align="center">

### 💡 _Built with ❤️ for the DevOps Community_

**[⬆ Back to Top](#-rk-cli-utils)**

</div>
