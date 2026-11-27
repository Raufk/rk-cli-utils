#!/usr/bin/env bash
set -euo pipefail

REPO="Raufk/rk-cli-utils"
LATEST_URL="https://github.com/${REPO}/releases/latest/download"

# SHA-256 of the release packages. Update these with every release.
DEB_SHA256="5fdaad20e1dc2c54609779d4cac0ea80e910f830e5e6147a22af8b75495058bd"
RPM_SHA256="412874c3f904bc18927ab961584b8ed4547c1e9a604a939f98cf334f66e4cc07"

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
        echo "${DEB_SHA256}  ${TMP_DIR}/rk-cli-utils.deb" | sha256sum -c -
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
        curl -fsSL -o "${TMP_DIR}/rk-cli-utils.rpm" "${LATEST_URL}/rk-cli-utils.rpm"
        echo "${RPM_SHA256}  ${TMP_DIR}/rk-cli-utils.rpm" | sha256sum -c -
        $SUDO "$PKG_MGR" localinstall -y "${TMP_DIR}/rk-cli-utils.rpm"
        rk --version
        ;;
    *)
        echo "Unsupported OS: $os" >&2
        exit 1
        ;;
esac
