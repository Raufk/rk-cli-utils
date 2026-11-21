#!/usr/bin/env bash
# Setup the ssh-key

type die >/dev/null 2>&1 || die() { echo "Error: $1" >&2; exit 1; }

setup_ssh() {
    local user="$1"
    local email="$2"
    local keyFile="$3"
    local raw_host="${4:-github.com}"

    [[ -z "$user" ]] && die "user required"
    [[ -z "$email" ]] && die "email required"
    [[ -z "$keyFile" ]] && die "key file required"

    # Normalize host (strip schemes, ports, and trailing slashes)
    local host="$raw_host"
    host="${host#https://}"
    host="${host#http://}"
    host="${host%%/*}"
    local host_no_port="${host%%:*}"

    git config --global user.email "$email"
    git config --global user.name "$user"
    git config --global url."git@${host_no_port}:".insteadOf "https://${host_no_port}/"

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    if [[ -f "$HOME/.ssh/id_rsa" ]]; then
        echo "SSH key already exists, skipping copy"
    else
        if [[ -f "$keyFile" ]]; then
            cp "$keyFile" "$HOME/.ssh/id_rsa"
        elif grep -q "BEGIN .*PRIVATE KEY" <<< "$keyFile"; then
            printf "%s\n" "$keyFile" > "$HOME/.ssh/id_rsa"
        else
            die "Invalid keyFile: not a file or valid private key content"
        fi
        chmod 600 "$HOME/.ssh/id_rsa"
    fi

    # Scan for modern host key types (rsa, ecdsa, ed25519) and secure known_hosts
    if command -v ssh-keyscan >/dev/null 2>&1; then
        ssh-keyscan -t rsa,ecdsa,ed25519 "$host_no_port" >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
        chmod 600 "$HOME/.ssh/known_hosts" 2>/dev/null || true
    fi

    echo "SSH setup complete for $host_no_port"
}
