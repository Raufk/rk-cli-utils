#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

test_assert() {
    local desc="$1"
    shift
    if "$@"; then
        echo "✅ PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "❌ FAIL: $desc"
        FAIL=$((FAIL + 1))
    fi
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_TEST_DIR"' EXIT

# Generate mock RSA private key
KEY_FILE="$TMP_TEST_DIR/test_rsa.pem"
openssl genrsa -out "$KEY_FILE" 2048 2>/dev/null
chmod 600 "$KEY_FILE"
RAW_PEM="$(cat "$KEY_FILE")"

export SCRIPT_DIR="$ROOT_DIR/lib"
export PATH="$ROOT_DIR/bin:$ROOT_DIR/wrappers:$PATH"

# 1. Base CLI checks
test_assert "rk --version reports version" rk --version
test_assert "rk --help outputs usage" rk --help

# 2. SSH Setup checks
SSH_HOME="$TMP_TEST_DIR/home"
mkdir -p "$SSH_HOME"
test_assert "setup-ssh with file path" bash -c "HOME='$SSH_HOME' rk setup-ssh --user 'Test User' --email 'test@example.com' --key-file '$KEY_FILE' --host 'https://github.ibm.com:8443/'"
test_assert "setup-ssh created ~/.ssh/id_rsa" [ -f "$SSH_HOME/.ssh/id_rsa" ]
test_assert "setup-ssh rewrote Git config" bash -c "HOME='$SSH_HOME' git config --global --get-all url.'git@github.ibm.com:'.insteadOf | grep -q 'https://github.ibm.com/'"

# 3. Slack Payload check
test_assert "slack payload construction with delimiter" bash -c '
    source "'"$ROOT_DIR"'/lib/slack.sh"
    payload=$(construct_slack_payload "#channel" "good" "First line~Second line")
    echo "$payload" | jq -e ".attachments | length == 2" >/dev/null
'

# 4. git-app config actions
CFG_BASE="$TMP_TEST_DIR/cfg"
test_assert "git-app config init creates file" bash -c "XDG_CONFIG_HOME='$CFG_BASE' rk git-app config init"
test_assert "git-app config file exists" [ -f "$CFG_BASE/rk-cli-utils/git-app.conf" ]
test_assert "git-app config show runs" bash -c "XDG_CONFIG_HOME='$CFG_BASE' rk git-app config show | grep -q 'GH_APP_ID'"

# 5. git-app sps init
test_assert "git-app sps init outputs exports" bash -c "rk git-app sps init | grep -q 'export GH_APP_ID='"

# 6. Local Git repository commands via git-app
REPO_DIR="$TMP_TEST_DIR/repo"
git init "$REPO_DIR" >/dev/null
echo "hello" > "$REPO_DIR/file.txt"

test_assert "git-app add file" bash -c "cd '$REPO_DIR' && git-app add file.txt"
test_assert "git-app add status staged" bash -c "cd '$REPO_DIR' && git status --porcelain | grep -q 'A  file.txt'"

test_assert "git-app commit rejected without identity" bash -c "cd '$REPO_DIR' && env -u GIT_USER_NAME -u GIT_USER_EMAIL git-app commit 'No identity' 2>/dev/null; [ \$? -eq 2 ]"
test_assert "git-app commit" bash -c "cd '$REPO_DIR' && GIT_USER_NAME='Bot' GIT_USER_EMAIL='bot@ibm.com' git-app commit 'Initial commit'"
test_assert "git-app commit log exists" bash -c "cd '$REPO_DIR' && git log -1 --pretty=%B | grep -q 'Initial commit'"
test_assert "git-app commit rejected with invalid email" bash -c "cd '$REPO_DIR' && GIT_USER_NAME='Bot' GIT_USER_EMAIL='not-an-email' git-app commit 'Bad email' 2>/dev/null; [ \$? -eq 2 ]"

test_assert "git-app checkout -b" bash -c "cd '$REPO_DIR' && git-app checkout -b feature-test"
test_assert "git-app branch list" bash -c "cd '$REPO_DIR' && git-app branch | grep -q 'feature-test'"
test_assert "git-app status" bash -c "cd '$REPO_DIR' && git-app status | grep -q 'On branch feature-test'"

echo "change" >> "$REPO_DIR/file.txt"
test_assert "git-app diff" bash -c "cd '$REPO_DIR' && git-app diff | grep -q 'change'"
test_assert "git-app tag" bash -c "cd '$REPO_DIR' && git-app tag v1.0.0"

# 7. Remote Git operations dry-runs
export GH_APP_ID="1234"
export GH_APP_INSTALLATION_ID="5678"
export GH_HOST="https://github.ibm.com"
export GH_APP_PRIVATE_KEY="$KEY_FILE"

test_assert "git-app clone --dry-run (HTTPS)" rk git-app --dry-run clone --depth 1 https://github.ibm.com/org/repo.git
test_assert "git-app clone --dry-run (SSH git@)" rk git-app --dry-run clone git@github.ibm.com:org/repo.git
test_assert "git-app fetch --dry-run" bash -c "cd '$REPO_DIR' && git remote add origin https://github.ibm.com/org/repo.git 2>/dev/null || true; rk git-app --dry-run fetch --prune origin"
test_assert "git-app fetch --all --dry-run" bash -c "cd '$REPO_DIR' && rk git-app --dry-run fetch --all"
test_assert "git-app pull --dry-run" bash -c "cd '$REPO_DIR' && rk git-app --dry-run pull --rebase origin feature-test"
test_assert "git-app push rejected without identity" bash -c "cd '$REPO_DIR' && env -u GIT_USER_NAME -u GIT_USER_EMAIL rk git-app --dry-run push -u origin feature-test 2>/dev/null; [ \$? -eq 2 ]"
test_assert "git-app push --dry-run" bash -c "cd '$REPO_DIR' && GIT_USER_NAME='Bot' GIT_USER_EMAIL='bot@ibm.com' rk git-app --dry-run push -u origin feature-test"
test_assert "git-app push --tags --dry-run" bash -c "cd '$REPO_DIR' && GIT_USER_NAME='Bot' GIT_USER_EMAIL='bot@ibm.com' rk git-app --dry-run push --tags origin"
test_assert "git-app ls-remote --dry-run" rk git-app --dry-run ls-remote https://github.ibm.com/org/repo.git
test_assert "git-app check --dry-run" rk git-app --dry-run check https://github.ibm.com/org/repo.git
test_assert "git-app session --dry-run" rk git-app --dry-run session --repo https://github.ibm.com/org/repo.git -- echo "hello"
test_assert "git-app token --dry-run" rk git-app --dry-run token --all-repos
test_assert "git-app revoke --dry-run" bash -c "GH_HOST=https://github.ibm.com GH_APP_TOKEN=ghs_test123 rk git-app --dry-run revoke"

# 8. Raw PEM string support
test_assert "git-app with raw PEM string key" bash -c "GH_APP_ID=1234 GH_APP_INSTALLATION_ID=5678 GH_HOST=https://github.ibm.com GH_APP_PRIVATE_KEY='$RAW_PEM' rk git-app --dry-run check https://github.ibm.com/org/repo.git"

# 9. Dynamic get_env support
MOCK_BIN="$TMP_TEST_DIR/mock_bin"
mkdir -p "$MOCK_BIN"
cat << EOF > "$MOCK_BIN/get_env"
#!/bin/sh
case "\$1" in
    git-app-id) echo "1234" ;;
    git-app-installation-id) echo "5678" ;;
    git-host) echo "https://github.ibm.com" ;;
    git-app-private-key) cat "$KEY_FILE" ;;
esac
EOF
chmod +x "$MOCK_BIN/get_env"
test_assert "git-app with dynamic get_env in PATH" env -i PATH="$MOCK_BIN:$ROOT_DIR/bin:$ROOT_DIR/wrappers:$PATH" HOME="$TMP_TEST_DIR" SCRIPT_DIR="$ROOT_DIR/lib" rk git-app --dry-run check https://github.ibm.com/org/repo.git

# 10. Security denial check
test_assert "git-app rejects dangerous --upload-pack option" bash -c "! rk git-app --dry-run clone --upload-pack /bad/exec https://github.ibm.com/org/repo.git 2>/dev/null"

echo "=========================================="
echo "TOTAL: Passed: $PASS, Failed: $FAIL"
echo "=========================================="
[ "$FAIL" -eq 0 ]
