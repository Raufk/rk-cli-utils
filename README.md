<div align="center">

# 🚀 rk-cli-utils

### _Supercharge Your DevOps Workflow_ ⚡

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.1-blue.svg)](https://github.com/Raufk/rk-cli-utils/releases)
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

> Perform Git operations using short-lived, repo-scoped GitHub App installation tokens

```bash
# Configure credentials via environment or config file
export GH_APP_ID="6566"
export GH_INSTALLATION_ID="47638"
export GH_PRIVATE_KEY="/secure/path/github-app-private-key.pem"
export GH_HOST="https://github.example.com"

# Clone, stage, commit and push with on-demand token authentication
git-app clone --depth 1 --branch main https://github.example.com/org/repo.git
cd repo
git-app add .
git-app commit "Update configuration"
git-app push origin main

# Validate credentials or run batch sessions
git-app check
git-app session --write -- make release
```

**Key Features:**

- 🛡️ **Zero Token Leakage:** In-memory credential passing via `GIT_ASKPASS`, automatic token revocation on exit, and log redaction
- 🎯 **Least Privilege:** Short-lived tokens scoped strictly to the target repository (`read` or `write`)
- 🔄 **Standard Git Passthrough:** Supports standard flags (`--depth`, `--branch`, `--force-with-lease`, `--rebase`, `--prune`, etc.)
- 🏢 **Multi-Profile Support:** Manage multiple GitHub hosts, Apps, or organizations in a single config
- 🔁 **Resilient:** Automatic retries with exponential back-off and rate-limit (`Retry-After`) handling
- ⚡ **Workflow & Docker Integration:** Reusable session tokens and BuildKit secret integration (`git-app session`, `git-app token`)

📖 **[Full git-app Documentation](docs/git-app.md)** — Complete guide with configuration reference, multi-profile examples, Docker BuildKit recipes, and troubleshooting.

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
curl -LO https://github.com/Raufk/rk-cli-utils/releases/download/v1.1/rk-cli-utils.deb

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
sudo yum install https://github.com/Raufk/rk-cli-utils/releases/download/v1.1/rk-cli-utils-1.1-1.el9.noarch.rpm

# Or download first, then install
wget https://github.com/Raufk/rk-cli-utils/releases/download/v1.1/rk-cli-utils-1.1-1.el9.noarch.rpm
sudo yum localinstall rk-cli-utils-1.1-1.el9.noarch.rpm

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

Commands can be invoked directly (e.g. `git-app`) or through the main CLI dispatcher `rk` (e.g. `rk git-app`):

| Command | Action / Description | Example |
| :--- | :--- | :--- |
| `setup-ssh` | Configure SSH & Git credentials | `setup-ssh --email dev@co.com --user "Dev" --key-file ~/.ssh/id_rsa` |
| `slack-send` | Send Slack notifications | `slack-send --token $TOKEN --channel "#ops" --message "Deployed!"` |
| `get-slack-id` | Look up Slack user ID by email | `get-slack-id --email user@co.com --token $TOKEN` |
| `git-app clone` | Clone repository via App token | `git-app clone https://github.com/org/repo.git` |
| `git-app fetch` | Fetch refs (`--all`, `--prune`, `--tags`) | `git-app fetch --all` |
| `git-app pull` | Pull and rebase/merge | `git-app pull --rebase origin main` |
| `git-app push` | Push changes safely | `git-app push --force-with-lease origin main` |
| `git-app add` | Stage changes locally | `git-app add .` |
| `git-app commit` | Commit with configured identity | `git-app commit -m "Release v1.2.0"` |
| `git-app check` | Validate App, key, and install access | `git-app check` |
| `git-app session` | Reusable token for batch workflows | `git-app session --write -- make release` |
| `git-app token` | Mint standalone token (e.g. Docker) | `TOKEN=$(git-app token --all-repos)` |
| `git-app revoke` | Revoke standalone token early | `printf '%s' "$TOKEN" \| git-app revoke` |
| `git-app config` | Manage configs and profiles | `git-app config init` / `git-app config show` |

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

<details>
<summary><b>🔑 GitHub App Git Examples</b></summary>

#### Clone, Commit, and Push
```bash
# Clone repository
git-app clone https://github.com/org/repo.git
cd repo

# Stage, commit, and push
git-app add .
git-app commit "feat: add automated build config"
git-app push origin main
```

#### Pre-flight Verification & Dry-run
```bash
# Verify credentials, installation, and permissions
git-app check

# Inspect what would run without network calls or minting a token
git-app --dry-run push origin main
```

#### Docker & Multi-Repo Workflows
```bash
# Mint token for all repositories in the installation
TOKEN=$(git-app token --all-repos)

# Use in Docker BuildKit build
DOCKER_BUILDKIT=1 docker build --secret id=gh_token,env=TOKEN -t my-app:latest .

# Revoke token when done
printf '%s' "$TOKEN" | git-app revoke
```

👉 See **[docs/git-app.md](docs/git-app.md)** for full documentation and configuration guides.

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
├── 📁 docs/
│   └── git-app.md           # In-depth git-app documentation
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
