#!/usr/bin/env bash
set -euo pipefail

REPO="Raufk/rk-cli-utils"
LATEST_URL="https://github.com/${REPO}/releases/latest/download"

# Determine privilege escalation (root vs sudo)
SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        echo "Error: Root privileges or 'sudo' required to install packages." >&2
        exit 1
    fi
fi

# detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"          # ubuntu, debian, rhel, centos, rocky, almalinux...
    else
        echo "unknown"
    fi
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

os=$(detect_os)
case "$os" in
    ubuntu|debian|pop|mint)
        echo "Ubuntu/Debian detected. Installing latest rk-cli-utils..."
        curl -fsSL -o "${TMP_DIR}/rk-cli-utils.deb" "${LATEST_URL}/rk-cli-utils.deb"
        export DEBIAN_FRONTEND=noninteractive
        $SUDO dpkg -i "${TMP_DIR}/rk-cli-utils.deb" || $SUDO apt-get install -f -y
        rk --version
        ;;
    rhel|centos|rocky|almalinux|fedora|ol|amzn)
        echo "RHEL-based detected. Installing latest rk-cli-utils..."
        if command -v dnf >/dev/null 2>&1; then
            PKG_MGR="dnf"
        else
            PKG_MGR="yum"
        fi
        if ! $SUDO "$PKG_MGR" install -y "${LATEST_URL}/rk-cli-utils.rpm"; then
            curl -fsSL -o "${TMP_DIR}/rk-cli-utils.rpm" "${LATEST_URL}/rk-cli-utils.rpm"
            $SUDO "$PKG_MGR" localinstall -y "${TMP_DIR}/rk-cli-utils.rpm"
        fi
        rk --version
        ;;
    *)
        echo "Unsupported OS: $os" >&2
        exit 1
        ;;
esac
