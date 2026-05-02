#!/usr/bin/env bash
# Setup the ssh-key
setup_ssh() {
    local user="$1"
    local email="$2"
    local keyFile="$3"
    local host="${4:-github.com}"   # default to github.com if not provided

    [[ -z "$user" ]] && die "user required"
    [[ -z "$email" ]] && die "email required"
    [[ -z "$keyFile" ]] && die "key file required"

    git config --global user.email "$email"
    git config --global user.name "$user"
    git config --global url."git@${host}:".insteadOf "https://${host}/"

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

    # Use dynamic host here
    ssh-keyscan -t rsa "$host" >> "$HOME/.ssh/known_hosts" 2>/dev/null

    echo "SSH setup complete for $host"
}
