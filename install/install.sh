#!/usr/bin/env bash
set -euo pipefail

REPO="Raufk/rk-cli-utils"
LATEST_URL="https://github.com/${REPO}/releases/latest/download"

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
        sudo dpkg -i "${TMP_DIR}/rk-cli-utils.deb" || sudo apt-get install -f -y
        rk --version
        ;;
    rhel|centos|rocky|almalinux|fedora|ol|amzn)
        echo "RHEL-based detected. Installing latest rk-cli-utils..."
        if command -v dnf >/dev/null 2>&1; then
            PKG_MGR="dnf"
        else
            PKG_MGR="yum"
        fi
        if ! sudo "$PKG_MGR" install -y "${LATEST_URL}/rk-cli-utils.rpm"; then
            curl -fsSL -o "${TMP_DIR}/rk-cli-utils.rpm" "${LATEST_URL}/rk-cli-utils.rpm"
            sudo "$PKG_MGR" localinstall -y "${TMP_DIR}/rk-cli-utils.rpm"
        fi
        rk --version
        ;;
    *)
        echo "Unsupported OS: $os"
        exit 1
        ;;
esac
