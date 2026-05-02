#!/usr/bin/env bash
# detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"          # ubuntu, rhel, centos, rocky, almalinux...
    else
        echo "unknown"
    fi
}

# =========== main ===========
os=$(detect_os)
case "$os" in
    ubuntu|debian)
        echo "Ubuntu/Debian detected"
        ;;
    rhel|centos|rocky|almalinux)
        echo "RHEL-based detected"
        sudo yum install https://github.com/Raufk/rk-cli-utils/releases/download/v1.0/rk-cli-utils-1.0-1.el9.noarch.rpm
        ;;
    *)
        echo "Unsupported OS: $os"
        exit 1
        ;;
esac
