#!/usr/bin/env bash
# GitHub Enterprise Git operations using a GitHub App installation token.
# Actions: clone, add, commit, fetch, pull, push, check, session, token, config
#
# Sourced by bin/rk, which runs with `set -euo pipefail`.
# Compatible with bash 3.2+ (macOS) and later.
#
# Exit codes: 0 success, 1 general error, 2 usage/configuration error,
#             3 network/API error (authentication, permission, availability).

# Configuration keys that may be set in the environment or a config file.
_GHA_CONFIG_KEYS="GH_APP_ID GH_INSTALLATION_ID GH_PRIVATE_KEY GH_HOST GH_API_URL GIT_USER_NAME GIT_USER_EMAIL GIT_APP_PROFILE GIT_APP_RETRIES GIT_APP_RETRY_DELAY GIT_APP_LOG_LEVEL GIT_APP_LOG_FILE"

_GHA_ENV_KEYS=""          # config keys that were set in the environment (env wins over files)
_GHA_LOG_LEVEL=2          # 0=error 1=warn 2=info 3=debug
_GHA_CLI_LEVEL=""         # level forced by --verbose/--quiet
_GHA_CONFIG_FILE=""       # explicit --config / GIT_APP_CONFIG
_GHA_CLI_PROFILE=""       # --profile
_GHA_PROFILE=""           # effective profile ("" = none)
_GHA_PROFILES=""          # profile names found in config files
_GHA_DRY_RUN=0            # 1 = validate locally only, no network, no token
_GHA_TOKEN=""             # installation token (memory only)
_GHA_JWT=""               # App JWT (memory only)
_GHA_SESSION_REUSED=0     # 1 = token came from an enclosing `git-app session`
_GHA_KEEP_TOKEN=0         # 1 = do not revoke the token on exit (`git-app token`)
_GHA_TOKEN_EXPIRES=""     # expires_at of the minted token (informational)
_GHA_TMP_DIR=""
_GHA_API_BASE=""
_GHA_ASKPASS=""
_GHA_REPO_OWNER=""
_GHA_REPO_NAME=""
_GHA_HTTP_CODE=""
_GHA_HTTP_BODY=""

# Parsed config entries, in file/precedence order (parallel arrays).
_GHA_CFG_N=0
_GHA_CFG_SEC=()
_GHA_CFG_KEY=()
_GHA_CFG_VAL=()
_GHA_CFG_SRC=()

# Result of _gha_parse_git_args: positional arguments and git pass-through options.
_GHA_POS=()
_GHA_OPTS=()
# Git command (without the leading `git -c credential.helper=`) to execute.
_GHA_CMD=()

# --------------------------------------------------------------------------
# Help / version
# --------------------------------------------------------------------------
git_app_usage() {
    cat <<EOF
Usage:
    rk git-app [global options] <action> [action options] [args]
    git-app    [global options] <action> [action options] [args]

Actions:
    clone [git-clone options] <https-repo-url> [directory]
    add [paths...]                    (default: add -A)
    commit "message" | commit [git-commit options]
    fetch [git-fetch options] [remote] [refspec...]
    pull  [git-pull options]  [remote] [refspec...]
    push  [git-push options]  [remote] [refspec...]
    check [repo-url | remote]         Validate configuration, App, installation
                                      and (optionally) repository access
    session [--write] [--all-repos | --repo <url|remote>] [-- command [args...]]
                                      Mint ONE token, run a command or shell with
                                      it, and revoke it on exit. git-app calls
                                      made inside reuse the token.
    token [--write] [--all-repos | --repo <url|remote>]
                                      Mint ONE token and print ONLY the token on
                                      stdout. It is NOT revoked: it stays valid
                                      until it expires (1 hour). Use it as
                                          TOKEN=\$(git-app token --all-repos)
                                          TOKEN=\$(git-app token --repo <url>)
                                      Revoke early with: git-app revoke
    revoke                            Revoke the token in \$GH_APP_TOKEN (or stdin)
    config [show]                     Show effective configuration and sources
    config init                       Create a config file template
    config profiles                   List profile names
    help | version

Global options (before the action):
    --profile <name>  Use the [name] section of the config files
    --config <file>   Extra config file (highest file precedence)
    --dry-run         Validate locally, show what would happen; no network
                      calls, no token minted, nothing modified
    --verbose         Debug logging
    --quiet           Only warnings and errors
    -h, --help        Show this help
    -V, --version     Show version

Git options are passed through to git after the action, for example:
    git-app clone --depth 1 --branch main https://host/org/repo.git
    git-app fetch --prune --tags origin
    git-app pull --rebase origin main
    git-app push --force-with-lease origin main
    git-app push --tags origin
Options that take a value work as "--opt value" for the common ones and always
as "--opt=value". Use "--" to end options. Options that could redirect the
token to another server or run external programs (--repo, --upload-pack,
--receive-pack, --exec, and clone -c/--config for credential/url/hook keys)
are refused. "push" with no refspec pushes the current branch, except with
--tags/--all/--mirror; "push --delete" always needs an explicit branch.

Configuration (environment variables override config files):
    GH_APP_ID            GitHub App ID (or client ID)
    GH_INSTALLATION_ID   App installation ID
    GH_PRIVATE_KEY       Path to the App private-key PEM (unencrypted, mode 600)
    GH_HOST              e.g. https://github.example.com (or https://github.com)
    GH_API_URL           API base URL (auto-detected: https://api.github.com or \$GH_HOST/api/v3)
    GIT_USER_NAME / GIT_USER_EMAIL   Local commit identity (set both or neither)
    GIT_APP_PROFILE      Default profile (same as --profile)
    GIT_APP_RETRIES      Retries on HTTP 429/5xx (default 3, 0 disables)
    GIT_APP_RETRY_DELAY  Base back-off in seconds (default 2, doubles per retry)
    GIT_APP_LOG_LEVEL    error | warn | info | debug (default: info)
    GIT_APP_LOG_FILE     Also append logs (tokens redacted) to this file

Config files, lowest to highest precedence:
    /etc/rk-cli-utils/git-app.conf
    \${XDG_CONFIG_HOME:-~/.config}/rk-cli-utils/git-app.conf
    \$GIT_APP_CONFIG or --config <file>
Files hold KEY=VALUE lines. Keys before any [section] are defaults; a [name]
section holds a profile whose values override the defaults. A top-level
GIT_APP_PROFILE=name selects the default profile. Files are parsed, never
executed, and secrets (tokens) are never read from them.

Notes:
    push requires the App to have Contents: Read and write permission.
    Run add/commit/fetch/pull/push from inside the target Git working tree.
    "origin" is the Git remote name, not the local directory name.
    A session token is held in memory and in the environment of the session
    command only (GIT_APP_SESSION_*); it is valid for the one repository.
    "token" output is a live credential: keep it in a variable, never in a file
    in the repo, an image layer or a log. For docker build prefer a build
    secret (docker build --secret id=gh_token,env=TOKEN) over --build-arg.
    Shell completion: see completions/ (installed by the packages).
    Exit codes: 0 ok, 1 error, 2 usage/config error, 3 network/API error.
EOF
}

git_app_version() {
    printf 'git-app (rk-cli-utils) %s\n' "${VERSION:-dev}"
}

# --------------------------------------------------------------------------
# Logging (stderr, with secret redaction)
# --------------------------------------------------------------------------
_gha_level_num() {
    case "$1" in
        error) echo 0 ;;
        warn | warning) echo 1 ;;
        info) echo 2 ;;
        debug) echo 3 ;;
        *) return 1 ;;
    esac
}

_gha_redact() {
    local msg="$1"
    if [[ -n "$_GHA_TOKEN" ]]; then msg="${msg//"$_GHA_TOKEN"/***REDACTED***}"; fi
    if [[ -n "$_GHA_JWT" ]]; then msg="${msg//"$_GHA_JWT"/***REDACTED***}"; fi
    # Defence in depth: mask anything that looks like a GitHub token or a JWT.
    if [[ "$msg" == *gh?_* || "$msg" == *eyJ* ]]; then
        msg="$(printf '%s' "$msg" | sed -E \
            -e 's/gh[pousr]_[A-Za-z0-9]{16,}/***REDACTED***/g' \
            -e 's/eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*/***REDACTED***/g')"
    fi
    printf '%s' "$msg"
}

_gha_log() {
    local level="$1" n msg tag
    shift
    n="$(_gha_level_num "$level")" || n=2
    if (( n > _GHA_LOG_LEVEL )); then return 0; fi
    msg="$(_gha_redact "$*")"
    tag="$(printf '%s' "$level" | tr '[:lower:]' '[:upper:]')"
    printf '[git-app] %-5s %s\n' "$tag" "$msg" >&2
    if [[ -n "${GIT_APP_LOG_FILE:-}" ]]; then
        (
            umask 077
            printf '%s %-5s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$tag" "$msg" \
                >> "$GIT_APP_LOG_FILE"
        ) 2>/dev/null || true
    fi
    return 0
}

# _gha_fail <exit-code> <message> [hint]
_gha_fail() {
    local code="$1"
    _gha_log error "$2"
    if [[ -n "${3:-}" ]]; then _gha_log error "  hint: $3"; fi
    exit "$code"
}

# --------------------------------------------------------------------------
# Small helpers
# --------------------------------------------------------------------------
_gha_stat_mode() { stat -L -c '%a' "$1" 2>/dev/null || stat -L -f '%Lp' "$1" 2>/dev/null; }
_gha_stat_uid() { stat -L -c '%u' "$1" 2>/dev/null || stat -L -f '%u' "$1" 2>/dev/null; }

_gha_lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Shell-quote a command for display.
_gha_quote_cmd() {
    local out="" a
    for a in "$@"; do out="$out $(printf '%q' "$a")"; done
    printf '%s' "${out# }"
}

_gha_require_commands() {
    local c
    for c in "$@"; do
        command -v "$c" >/dev/null 2>&1 || _gha_fail 2 "Required command not found: $c"
    done
}

_gha_user_config_path() {
    printf '%s/rk-cli-utils/git-app.conf' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

# --------------------------------------------------------------------------
# Configuration management (files, profiles, precedence)
# --------------------------------------------------------------------------
_gha_load_config_file() {
    local file="$1" mode uid line key val lineno=0 section=""
    local re='^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$'
    local sre='^[[:space:]]*\[([A-Za-z0-9._-]+)\][[:space:]]*(#.*)?$'

    mode="$(_gha_stat_mode "$file")" || mode=""
    uid="$(_gha_stat_uid "$file")" || uid=""
    [[ -n "$mode" && -n "$uid" ]] || _gha_fail 2 "Cannot inspect config file: $file"
    if [[ "$uid" != "$(id -u)" && "$uid" != "0" ]]; then
        _gha_fail 2 "Config file must be owned by you or root: $file"
    fi
    if (( (8#$mode & 8#022) != 0 )); then
        _gha_fail 2 "Config file is writable by group/others ($mode): $file" "chmod go-w '$file'"
    fi

    _gha_log debug "Loading config file: $file"
    while IFS= read -r line || [[ -n "$line" ]]; do
        lineno=$((lineno + 1))
        line="${line%$'\r'}"
        if [[ "$line" =~ ^[[:space:]]*(#|$) ]]; then continue; fi
        if [[ "$line" =~ $sre ]]; then
            section="${BASH_REMATCH[1]}"
            case " $_GHA_PROFILES " in
                *" $section "*) ;;
                *) _GHA_PROFILES="$_GHA_PROFILES $section" ;;
            esac
            continue
        fi
        if ! [[ "$line" =~ $re ]]; then
            _gha_fail 2 "$file:$lineno: invalid line (expected KEY=VALUE or [profile])"
        fi
        key="${BASH_REMATCH[2]}"
        val="${BASH_REMATCH[3]}"
        val="${val#"${val%%[![:space:]]*}"}"
        val="${val%"${val##*[![:space:]]}"}"
        if [[ ${#val} -ge 2 && ( "${val:0:1}" == '"' || "${val:0:1}" == "'" ) \
            && "${val: -1}" == "${val:0:1}" ]]; then
            val="${val:1:${#val}-2}"
        fi

        case " $_GHA_CONFIG_KEYS " in
            *" $key "*) ;;
            *)
                case "$key" in
                    *TOKEN* | *SECRET* | *PASSWORD*)
                        _gha_fail 2 "$file:$lineno: secret key '$key' is not allowed in config files" \
                            "Tokens are generated per operation and are never read from configuration."
                        ;;
                esac
                _gha_log warn "$file:$lineno: ignoring unknown key '$key'"
                continue
                ;;
        esac
        if [[ "$key" == "GIT_APP_PROFILE" && -n "$section" ]]; then
            _gha_log warn "$file:$lineno: GIT_APP_PROFILE is only valid outside [sections]; ignored"
            continue
        fi

        _GHA_CFG_SEC[_GHA_CFG_N]="$section"
        _GHA_CFG_KEY[_GHA_CFG_N]="$key"
        _GHA_CFG_VAL[_GHA_CFG_N]="$val"
        _GHA_CFG_SRC[_GHA_CFG_N]="$file"
        _GHA_CFG_N=$((_GHA_CFG_N + 1))
    done < "$file"
}

# Apply parsed entries: defaults first, then the selected profile on top.
# Environment variables always win.
_gha_apply_config() {
    local pass i key sec val src
    for pass in base profile; do
        for ((i = 0; i < _GHA_CFG_N; i++)); do
            sec="${_GHA_CFG_SEC[i]}"
            key="${_GHA_CFG_KEY[i]}"
            if [[ "$pass" == "base" ]]; then
                [[ -z "$sec" ]] || continue
            else
                [[ -n "$_GHA_PROFILE" && "$sec" == "$_GHA_PROFILE" ]] || continue
            fi
            [[ "$key" != "GIT_APP_PROFILE" ]] || continue
            case " $_GHA_ENV_KEYS " in *" $key "*) continue ;; esac

            val="${_GHA_CFG_VAL[i]}"
            case "$key" in
                GH_PRIVATE_KEY | GIT_APP_LOG_FILE)
                    if [[ "$val" == "~/"* ]]; then val="$HOME/${val#\~/}"; fi ;;
            esac
            src="${_GHA_CFG_SRC[i]}"
            if [[ -n "$sec" ]]; then src="$src [$sec]"; fi
            printf -v "$key" '%s' "$val"
            printf -v "_GHA_SRC_$key" '%s' "$src"
        done
    done
}

_gha_load_config() {
    local k f i profile_src=""
    _GHA_ENV_KEYS=""
    for k in $_GHA_CONFIG_KEYS; do
        if [[ -n "${!k:-}" ]]; then
            _GHA_ENV_KEYS="$_GHA_ENV_KEYS $k"
            printf -v "_GHA_SRC_$k" '%s' "environment"
        else
            printf -v "$k" '%s' ""
            printf -v "_GHA_SRC_$k" '%s' "unset"
        fi
    done

    for f in "/etc/rk-cli-utils/git-app.conf" "$(_gha_user_config_path)"; do
        if [[ -f "$f" ]]; then _gha_load_config_file "$f"; fi
    done

    f="${_GHA_CONFIG_FILE:-${GIT_APP_CONFIG:-}}"
    if [[ -n "$f" ]]; then
        [[ -f "$f" ]] || _gha_fail 2 "Config file not found: $f"
        _gha_load_config_file "$f"
    fi

    # Profile: --profile > environment > top-level GIT_APP_PROFILE in files.
    _GHA_PROFILE=""
    if [[ -n "$_GHA_CLI_PROFILE" ]]; then
        _GHA_PROFILE="$_GHA_CLI_PROFILE"
        profile_src="--profile"
    elif [[ -n "$GIT_APP_PROFILE" ]]; then
        _GHA_PROFILE="$GIT_APP_PROFILE"
        profile_src="environment"
    else
        for ((i = 0; i < _GHA_CFG_N; i++)); do
            if [[ -z "${_GHA_CFG_SEC[i]}" && "${_GHA_CFG_KEY[i]}" == "GIT_APP_PROFILE" ]]; then
                _GHA_PROFILE="${_GHA_CFG_VAL[i]}"
                profile_src="${_GHA_CFG_SRC[i]}"
            fi
        done
    fi
    if [[ -n "$_GHA_PROFILE" ]]; then
        [[ "$_GHA_PROFILE" =~ ^[A-Za-z0-9._-]+$ ]] ||
            _gha_fail 2 "Invalid profile name: $_GHA_PROFILE"
        case " $_GHA_PROFILES " in
            *" $_GHA_PROFILE "*) ;;
            *) _gha_fail 2 "Profile '$_GHA_PROFILE' not found in any config file." \
                "Available profiles:${_GHA_PROFILES:- (none)}. Define a [$_GHA_PROFILE] section in $(_gha_user_config_path)." ;;
        esac
    fi
    GIT_APP_PROFILE="$_GHA_PROFILE"
    _GHA_SRC_GIT_APP_PROFILE="${profile_src:-unset}"

    _gha_apply_config

    # Defaults and validation for retry/log settings.
    if [[ -z "$GIT_APP_RETRIES" ]]; then
        GIT_APP_RETRIES=3
        _GHA_SRC_GIT_APP_RETRIES="default"
    fi
    if [[ -z "$GIT_APP_RETRY_DELAY" ]]; then
        GIT_APP_RETRY_DELAY=2
        _GHA_SRC_GIT_APP_RETRY_DELAY="default"
    fi
    [[ "$GIT_APP_RETRIES" =~ ^[0-9]+$ && "$GIT_APP_RETRIES" -le 10 ]] ||
        _gha_fail 2 "GIT_APP_RETRIES must be a number from 0 to 10: $GIT_APP_RETRIES"
    [[ "$GIT_APP_RETRY_DELAY" =~ ^[0-9]+$ && "$GIT_APP_RETRY_DELAY" -le 30 ]] ||
        _gha_fail 2 "GIT_APP_RETRY_DELAY must be a number from 0 to 30: $GIT_APP_RETRY_DELAY"

    # Log level: CLI flag > config/env > default.
    if [[ -n "$_GHA_CLI_LEVEL" ]]; then
        _GHA_LOG_LEVEL="$(_gha_level_num "$_GHA_CLI_LEVEL")"
    elif [[ -n "$GIT_APP_LOG_LEVEL" ]]; then
        _GHA_LOG_LEVEL="$(_gha_level_num "$GIT_APP_LOG_LEVEL")" ||
            _gha_fail 2 "Invalid GIT_APP_LOG_LEVEL: $GIT_APP_LOG_LEVEL" "Use error, warn, info or debug."
    fi
}

_gha_config_show() {
    local k src val
    printf '%-20s %-40s %s\n' "KEY" "VALUE" "SOURCE"
    for k in $_GHA_CONFIG_KEYS; do
        val="${!k}"
        src="_GHA_SRC_$k"
        printf '%-20s %-40s %s\n' "$k" "${val:--}" "${!src}"
    done
}

_gha_config_profiles() {
    local p
    for p in $_GHA_PROFILES; do printf '%s\n' "$p"; done
}

_gha_config_init() {
    local path dir
    path="$(_gha_user_config_path)"
    dir="$(dirname "$path")"
    [[ ! -e "$path" ]] || _gha_fail 2 "Config file already exists: $path"
    mkdir -p "$dir"
    chmod 700 "$dir"
    (
        umask 077
        cat > "$path" <<'CONF_EOF'
# git-app configuration (KEY=VALUE, no shell expansion).
# Environment variables override these values.
# Never put tokens here; they are generated per operation.

# --- Defaults (used when no profile overrides them) ---
GH_APP_ID=
GH_INSTALLATION_ID=
GH_PRIVATE_KEY=~/.ssh/github-app-private-key.pem
GH_HOST=https://github.example.com
# GH_API_URL=https://github.example.com/api/v3

# GIT_USER_NAME=Your Name
# GIT_USER_EMAIL=you@example.com

# GIT_APP_RETRIES=3
# GIT_APP_RETRY_DELAY=2
# GIT_APP_LOG_LEVEL=info
# GIT_APP_LOG_FILE=~/.local/state/rk-cli-utils/git-app.log

# Profile used when --profile / GIT_APP_PROFILE are not given:
# GIT_APP_PROFILE=work

# --- Profiles: select with --profile <name>; values override the defaults ---
# [work]
# GH_HOST=https://github.work.example.com
# GH_APP_ID=1234
# GH_INSTALLATION_ID=5678
# GH_PRIVATE_KEY=~/.ssh/work-app.pem
#
# [oss]
# GH_HOST=https://github.com
# GH_API_URL=https://api.github.com
# GH_APP_ID=4321
# GH_INSTALLATION_ID=8765
# GH_PRIVATE_KEY=~/.ssh/oss-app.pem
CONF_EOF
    )
    _gha_log info "Created config template: $path (mode 600)"
}

_gha_require_remote_config() {
    local k missing=""
    for k in GH_APP_ID GH_INSTALLATION_ID GH_PRIVATE_KEY GH_HOST; do
        if [[ -z "${!k}" ]]; then missing="$missing $k"; fi
    done
    [[ -z "$missing" ]] || _gha_fail 2 "Missing required configuration:$missing" \
        "Set environment variables or a config file ($(_gha_user_config_path)); 'rk git-app config init' creates a template."

    [[ "$GH_APP_ID" =~ ^[A-Za-z0-9._-]+$ ]] ||
        _gha_fail 2 "GH_APP_ID contains invalid characters."
    [[ "$GH_INSTALLATION_ID" =~ ^[0-9]+$ ]] ||
        _gha_fail 2 "GH_INSTALLATION_ID must be numeric."

    _gha_configure_api_base
}

# Validate and establish the API base URL.
# Enforces strict origin and path boundaries to prevent credential leakage.
_gha_configure_api_base() {
    GH_HOST="${GH_HOST%/}"
    [[ "$GH_HOST" =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?$ ]] ||
        _gha_fail 2 "GH_HOST must look like https://host (HTTPS only, no path): $GH_HOST"

    local host_authority="${GH_HOST#https://}"
    local host_lower="$(_gha_lower "$GH_HOST")"

    if [[ -n "${GH_API_URL:-}" ]]; then
        local api_url="${GH_API_URL%/}"
        [[ "$api_url" =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?(/.*)?$ ]] ||
            _gha_fail 2 "GH_API_URL must be a valid HTTPS URL: $GH_API_URL"

        if [[ "$api_url" == *"@"* ]]; then
            _gha_fail 2 "GH_API_URL must not contain embedded user credentials: $GH_API_URL"
        fi

        if [[ "$host_lower" == "https://github.com" ]]; then
            local api_lower="$(_gha_lower "$api_url")"
            if [[ "$api_lower" != "https://api.github.com" &&
                  "$api_lower" != "https://api.github.com/api/v3" ]]; then
                _gha_fail 2 "Invalid GH_API_URL for github.com: $GH_API_URL" \
                    "For github.com, the API endpoint is https://api.github.com (or leave GH_API_URL unset)."
            fi
        else
            local api_authority="${api_url#https://}"
            api_authority="${api_authority%%/*}"
            if [[ "$(_gha_lower "$api_authority")" != "$(_gha_lower "$host_authority")" ]]; then
                _gha_fail 2 "GH_API_URL host ($api_authority) does not match GH_HOST ($host_authority)." \
                    "For GitHub Enterprise, API requests must target the configured enterprise host."
            fi
            local api_path="${api_url#https://"$api_authority"}"
            if [[ -z "$api_path" || "$api_path" != /api* ]]; then
                _gha_fail 2 "GH_API_URL for GitHub Enterprise must point to an API path (e.g. ${GH_HOST}/api/v3): $GH_API_URL"
            fi
        fi
        _GHA_API_BASE="$api_url"
    elif [[ "$host_lower" == "https://github.com" ]]; then
        _GHA_API_BASE="https://api.github.com"
    else
        _GHA_API_BASE="${GH_HOST}/api/v3"
    fi
}

# --------------------------------------------------------------------------
# Private key protection
# --------------------------------------------------------------------------
_gha_check_private_key() {
    local key="$GH_PRIVATE_KEY" mode
    [[ -f "$key" ]] || _gha_fail 2 "Private key not found (or not a regular file): $key"
    [[ -r "$key" ]] || _gha_fail 2 "Private key is not readable: $key"

    mode="$(_gha_stat_mode "$key")" || mode=""
    if [[ -n "$mode" ]] && (( (8#$mode & 8#077) != 0 )); then
        if [[ "${GIT_APP_INSECURE_KEY_PERMS:-}" == "1" ]]; then
            _gha_log warn "Private key permissions are too open ($mode): $key"
        else
            _gha_fail 2 "Private key permissions are too open ($mode): $key" \
                "Run: chmod 600 '$key'  (or set GIT_APP_INSECURE_KEY_PERMS=1 for read-only secret mounts)"
        fi
    fi

    # -passin pass: and </dev/null stop openssl from ever prompting on a TTY.
    openssl pkey -in "$key" -noout -passin pass: </dev/null >/dev/null 2>&1 ||
        _gha_fail 2 "Private key is not a valid unencrypted PEM key: $key" \
            "Download the key from the GitHub App settings page; passphrase-protected keys are not supported."
}

# --------------------------------------------------------------------------
# GitHub API access, retry and error explanation
# --------------------------------------------------------------------------
_gha_base64url() {
    openssl base64 -A | tr '+/' '-_' | tr -d '='
}

# Secrets go to curl on stdin (--config -) so they never appear in argv/ps.
# Usage: _gha_curl_with_bearer <bearer-token> <curl args...>
_gha_curl_with_bearer() {
    local bearer="$1"
    shift
    printf 'header = "Authorization: Bearer %s"\n' "$bearer" |
        curl --config - "$@"
}

_gha_make_jwt() {
    local now iat exp h p s
    # 9-minute JWT (GitHub maximum is 10); iat is back-dated 60s for clock skew.
    now="$(date +%s)"
    iat=$((now - 60))
    exp=$((now + 540))
    h="$(printf '%s' '{"alg":"RS256","typ":"JWT"}' | _gha_base64url)"
    p="$(printf '{"iat":%s,"exp":%s,"iss":"%s"}' "$iat" "$exp" "$GH_APP_ID" | _gha_base64url)"
    # -passin pass: makes an encrypted key fail instead of prompting on the TTY.
    s="$(printf '%s' "${h}.${p}" |
        openssl dgst -sha256 -sign "$GH_PRIVATE_KEY" -passin pass: -binary 2>/dev/null |
        _gha_base64url)" || s=""
    [[ -n "$s" ]] || _gha_fail 2 "Failed to sign the App JWT with GH_PRIVATE_KEY." \
        "Verify the key is the App's RSA private key."
    _GHA_JWT="${h}.${p}.${s}"
}

_gha_json() {
    printf '%s' "$_GHA_HTTP_BODY" | jq -r "$1" 2>/dev/null || true
}

_gha_api_message() {
    _gha_json '.message // empty' | tr -d '\000-\037' | cut -c1-200
}

_gha_explain_curl() {
    local rc="$1" err="$2" hint
    err="$(printf '%s' "$err" | tr -d '\000-\037' | cut -c1-200)"
    case "$rc" in
        6) hint="Could not resolve the host. Check GH_HOST/GH_API_URL, DNS and VPN." ;;
        7) hint="Connection failed. Check GH_HOST/GH_API_URL, firewall, proxy and VPN." ;;
        28) hint="The request timed out. The server or network may be slow or unreachable." ;;
        35 | 51 | 58 | 60 | 77 | 82 | 83 | 90 | 91)
            hint="TLS/certificate problem. Install the CA that signed the server certificate; certificate validation is never disabled." ;;
        *) hint="See curl exit code $rc (man curl, EXIT CODES)." ;;
    esac
    _gha_fail 3 "Network error talking to GitHub (curl exit $rc${err:+: $err})" "$hint"
}

# Retry on rate limiting and server errors. A 403 is retried only when GitHub
# says when to come back (Retry-After header, secondary rate limit).
# _gha_is_retryable <http-code> <header-file>
_gha_is_retryable() {
    case "$1" in
        429 | 5??) return 0 ;;
        403) [[ -f "$2" ]] && tr -d '\r' < "$2" | grep -qi '^retry-after:' ;;
        *) return 1 ;;
    esac
}

# Seconds to wait before retry number <attempt> (0-based): Retry-After if sent,
# otherwise exponential back-off with jitter. Capped at 60 seconds.
# _gha_retry_wait <attempt> <header-file>
_gha_retry_wait() {
    local attempt="$1" hdr="$2" ra="" base="${GIT_APP_RETRY_DELAY:-2}" w i
    if [[ -f "$hdr" ]]; then
        ra="$(tr -d '\r' < "$hdr" | awk 'tolower($1)=="retry-after:" {print $2; exit}')"
    fi
    if [[ "$ra" =~ ^[0-9]+$ ]]; then
        w="$ra"
    else
        w="$base"
        for ((i = 0; i < attempt; i++)); do w=$((w * 2)); done
        w=$((w + RANDOM % (base / 2 + 1)))
    fi
    if (( w > 60 )); then w=60; fi
    printf '%s' "$w"
}

# _gha_api <METHOD> <url> <bearer> [json-body]
# Sets _GHA_HTTP_CODE and _GHA_HTTP_BODY. Retries 429/5xx with back-off.
# Exits on transport-level failure.
_gha_api() {
    local method="$1" url="$2" bearer="$3" data="${4:-}" out rc errtxt wait
    local attempt=0 max="${GIT_APP_RETRIES:-3}"
    local errfile="${_GHA_TMP_DIR}/curl.err" hdr="${_GHA_TMP_DIR}/curl.hdr"
    local -a args=(--silent --show-error --proto =https --connect-timeout 15 --max-time 60
        --request "$method" --header "Accept: application/vnd.github+json"
        --dump-header "$hdr" --write-out $'\n%{http_code}')
    if [[ -n "$data" ]]; then
        args+=(--header "Content-Type: application/json" --data "$data")
    fi

    while :; do
        _gha_log debug "API $method $url"
        rc=0
        out="$(_gha_curl_with_bearer "$bearer" "${args[@]}" "$url" 2>"$errfile")" || rc=$?
        if (( rc != 0 )); then
            errtxt="$(cat "$errfile" 2>/dev/null || true)"
            _gha_explain_curl "$rc" "$errtxt"
        fi
        _GHA_HTTP_CODE="${out##*$'\n'}"
        _GHA_HTTP_BODY="${out%$'\n'*}"
        _gha_log debug "API response: HTTP $_GHA_HTTP_CODE"

        if (( attempt < max )) && _gha_is_retryable "$_GHA_HTTP_CODE" "$hdr"; then
            wait="$(_gha_retry_wait "$attempt" "$hdr")"
            attempt=$((attempt + 1))
            _gha_log warn "HTTP $_GHA_HTTP_CODE from $method ${url#"$_GHA_API_BASE"}; retry $attempt/$max in ${wait}s"
            sleep "$wait"
            continue
        fi
        break
    done
}

# _gha_http_fail <context>   (never returns)
_gha_http_fail() {
    local context="$1" msg detail=""
    msg="$(_gha_api_message)"
    if [[ -n "$msg" ]]; then detail=" - GitHub says: $msg"; fi
    case "$_GHA_HTTP_CODE" in
        3??)
            _gha_fail 3 "$context: received unexpected HTTP redirect (HTTP $_GHA_HTTP_CODE)$detail" \
                "API redirects are rejected to prevent credential forwarding." ;;
        401)
            _gha_fail 3 "$context: authentication failed (HTTP 401)$detail" \
                "Check GH_APP_ID, that GH_PRIVATE_KEY is this App's key, and that the system clock is accurate (the JWT is time-limited)." ;;
        403)
            _gha_fail 3 "$context: access denied (HTTP 403)$detail" \
                "The App may be suspended or lack permission, or you may be rate-limited or blocked by an IP allow list." ;;
        404)
            _gha_fail 3 "$context: not found (HTTP 404)$detail" \
                "Check GH_INSTALLATION_ID, GH_HOST/GH_API_URL, and that the App is installed on this repository." ;;
        422)
            _gha_fail 3 "$context: request rejected (HTTP 422)$detail" \
                "The repository is not part of this installation, or the App lacks the requested Contents permission." ;;
        429)
            _gha_fail 3 "$context: rate limited (HTTP 429)$detail" \
                "Still limited after ${GIT_APP_RETRIES:-3} retries. Wait, or raise GIT_APP_RETRIES / GIT_APP_RETRY_DELAY." ;;
        5??)
            _gha_fail 3 "$context: GitHub server error (HTTP $_GHA_HTTP_CODE)$detail" \
                "Still failing after ${GIT_APP_RETRIES:-3} retries. Try again later." ;;
        *)
            _gha_fail 3 "$context: unexpected response (HTTP ${_GHA_HTTP_CODE:-none})$detail" ;;
    esac
}

# --------------------------------------------------------------------------
# Validation of App, installation, token and repository
# --------------------------------------------------------------------------
_gha_parse_repo_url() {
    local url="$1" path
    [[ "$url" == "$GH_HOST/"* ]] ||
        _gha_fail 2 "Remote URL must belong to $GH_HOST (https, no embedded credentials): $url" \
            "Fix with: git remote set-url <remote> $GH_HOST/<owner>/<repo>.git (or select another --profile)"
    path="${url#"$GH_HOST"/}"
    path="${path%/}"
    path="${path%.git}"
    [[ "$path" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] ||
        _gha_fail 2 "Expected repository URL in owner/repository format: $url"
    _GHA_REPO_OWNER="${path%%/*}"
    _GHA_REPO_NAME="${path##*/}"
}

_gha_validate_app() {
    local slug
    _gha_api GET "${_GHA_API_BASE}/app" "$_GHA_JWT"
    [[ "$_GHA_HTTP_CODE" == "200" ]] || _gha_http_fail "GitHub App lookup"
    slug="$(_gha_json '.slug // .name // empty')"
    _gha_log info "App credentials valid (app: ${slug:-unknown})"
}

_gha_validate_installation() {
    local login suspended
    _gha_api GET "${_GHA_API_BASE}/app/installations/${GH_INSTALLATION_ID}" "$_GHA_JWT"
    [[ "$_GHA_HTTP_CODE" == "200" ]] || _gha_http_fail "Installation lookup"

    suspended="$(_gha_json '.suspended_at // empty')"
    [[ -z "$suspended" ]] ||
        _gha_fail 3 "Installation $GH_INSTALLATION_ID is suspended (since $suspended)." \
            "Ask an organization owner to unsuspend the App."

    login="$(_gha_json '.account.login // empty')"
    if [[ -n "$_GHA_REPO_OWNER" && -n "$login" ]] &&
        [[ "$(_gha_lower "$login")" != "$(_gha_lower "$_GHA_REPO_OWNER")" ]]; then
        _gha_fail 2 "Installation $GH_INSTALLATION_ID belongs to '$login' but the repository owner is '$_GHA_REPO_OWNER'." \
            "Use the installation ID of the App on '$_GHA_REPO_OWNER' (or select another --profile)."
    fi
    _gha_log info "Installation $GH_INSTALLATION_ID valid (account: ${login:-unknown})"
}

# _gha_mint_token <read|write>
_gha_mint_token() {
    local perm="$1" request granted token
    if [[ -n "$_GHA_REPO_NAME" ]]; then
        request="$(jq -n --arg repo "$_GHA_REPO_NAME" --arg permission "$perm" \
            '{repositories: [$repo], permissions: {contents: $permission}}')"
        _gha_log info "Requesting installation token (contents: $perm) for ${_GHA_REPO_OWNER}/${_GHA_REPO_NAME}"
    else
        request="$(jq -n --arg permission "$perm" \
            '{permissions: {contents: $permission}}')"
        _gha_log info "Requesting installation token (contents: $perm) for all installation repositories"
    fi
    _gha_api POST "${_GHA_API_BASE}/app/installations/${GH_INSTALLATION_ID}/access_tokens" \
        "$_GHA_JWT" "$request"
    [[ "$_GHA_HTTP_CODE" == "201" ]] || _gha_http_fail "Token request"

    token="$(_gha_json '.token | select(type == "string" and length > 0)')"
    [[ -n "$token" ]] || _gha_fail 3 "GitHub returned no installation token." \
        "Check the App installation and permissions."
    _GHA_TOKEN="$token"
    _GHA_TOKEN_EXPIRES="$(_gha_json '.expires_at // empty')"
    _GHA_JWT=""

    granted="$(_gha_json '.permissions.contents // empty')"
    if [[ "$perm" == "write" && "$granted" != "write" ]] ||
        [[ "$perm" == "read" && "$granted" != "read" && "$granted" != "write" ]]; then
        _gha_fail 3 "Token does not carry the required Contents permission (wanted $perm, got '${granted:-none}')." \
            "Grant the App the Contents permission ($perm) in its settings and accept the update on the installation."
    fi
    _gha_log debug "Token granted contents: $granted (expires $(_gha_json '.expires_at // "unknown"'))"
}

_gha_validate_repo() {
    local perm="$1" archived can_push
    _gha_api GET "${_GHA_API_BASE}/repos/${_GHA_REPO_OWNER}/${_GHA_REPO_NAME}" "$_GHA_TOKEN"
    [[ "$_GHA_HTTP_CODE" == "200" ]] ||
        _gha_http_fail "Repository ${_GHA_REPO_OWNER}/${_GHA_REPO_NAME}"
    if [[ "$perm" == "write" ]]; then
        archived="$(_gha_json '.archived // false')"
        [[ "$archived" != "true" ]] ||
            _gha_fail 3 "Repository ${_GHA_REPO_OWNER}/${_GHA_REPO_NAME} is archived and read-only."
        can_push="$(_gha_json '.permissions.push // empty')"
        [[ "$can_push" != "false" ]] ||
            _gha_fail 3 "The App installation cannot push to ${_GHA_REPO_OWNER}/${_GHA_REPO_NAME}." \
                "Check the App's Contents permission and the repository selection of the installation."
    fi
    _gha_log info "Repository access verified: ${_GHA_REPO_OWNER}/${_GHA_REPO_NAME}"
}

# Full validation + token minting for the repository already parsed into
# _GHA_REPO_OWNER/_GHA_REPO_NAME. _gha_mint_and_validate <read|write>
_gha_mint_and_validate() {
    _gha_check_private_key
    _gha_make_jwt
    _gha_validate_installation
    _gha_mint_token "$1"
    if [[ -n "$_GHA_REPO_NAME" ]]; then
        _gha_validate_repo "$1"
    fi
}

# --------------------------------------------------------------------------
# Session token reuse
# --------------------------------------------------------------------------
# Reuse the token of an enclosing `git-app session` when it is for the same
# host and repository, has enough permission and is not about to expire.
# _gha_session_reuse <read|write>
_gha_session_reuse() {
    local need="$1" now exp want have
    [[ -n "${GIT_APP_SESSION_TOKEN:-}" ]] || return 1
    [[ "${GIT_APP_SESSION_HOST:-}" == "$GH_HOST" ]] || return 1

    want="$(_gha_lower "${_GHA_REPO_OWNER}/${_GHA_REPO_NAME}")"
    have="$(_gha_lower "${GIT_APP_SESSION_REPO:-}")"
    if [[ "$have" != "*" && "$want" != "$have" ]]; then
        _gha_log info "Session token is for '${GIT_APP_SESSION_REPO:-?}', not '${_GHA_REPO_OWNER}/${_GHA_REPO_NAME}'; requesting a separate token"
        return 1
    fi

    exp="${GIT_APP_SESSION_EXPIRES:-0}"
    [[ "$exp" =~ ^[0-9]+$ ]] || return 1
    now="$(date +%s)"
    if (( exp - now <= 60 )); then
        _gha_log info "Session token is about to expire; requesting a new token"
        return 1
    fi
    if [[ "$need" == "write" && "${GIT_APP_SESSION_PERM:-}" != "write" ]]; then
        _gha_log info "Session token is read-only; requesting a separate write token"
        return 1
    fi

    _GHA_TOKEN="$GIT_APP_SESSION_TOKEN"
    _GHA_SESSION_REUSED=1
    _gha_log info "Reusing session token for ${_GHA_REPO_OWNER}/${_GHA_REPO_NAME} (about $(((exp - now) / 60)) min left)"
    return 0
}

# --------------------------------------------------------------------------
# Git option pass-through
# --------------------------------------------------------------------------
# Options that take a separate value, per action (for "--opt value" parsing).
_gha_value_options() {
    case "$1" in
        clone) printf ' -b --branch --depth --filter -o --origin --reference --reference-if-able --separate-git-dir -j --jobs --shallow-since --shallow-exclude --template -c --config --server-option --bundle-uri --revision --ref-format ' ;;
        fetch) printf ' --depth --deepen --shallow-since --shallow-exclude -j --jobs --filter -o --server-option --negotiation-tip --refmap ' ;;
        pull) printf ' --depth --deepen --shallow-since --shallow-exclude -j --jobs --filter -s --strategy -X --strategy-option -o --server-option ' ;;
        push) printf ' -o --push-option ' ;;
        *) printf ' ' ;;
    esac
}

# Refuse options that could send the token to another server or run programs.
# git accepts unambiguous abbreviations of long options, so prefixes count.
# _gha_deny_option <action> <name>
_gha_deny_option() {
    local action="$1" name="$2" d denied
    case "$action" in
        clone) denied="-u --upload-pack --repo" ;;
        fetch | pull) denied="--upload-pack --repo" ;;
        push) denied="--receive-pack --exec --repo" ;;
        *) return 0 ;;
    esac
    for d in $denied; do
        # Exact match, an abbreviated long option, or a short option with its
        # value attached (git accepts "-u/bin/prog" as well as "-u /bin/prog").
        if [[ "$name" == "$d" ]] ||
            { [[ "$name" == --?* && "$d" == --* && "$d" == "$name"* ]]; } ||
            { [[ "$d" != --* && "$name" != --* && "$name" == "$d"* ]]; }; then
            _gha_fail 2 "Option '$name' is not allowed with git-app $action." \
                "It could send the installation token to another server or run an external program."
        fi
    done
}

# Refuse clone -c/--config values that change credentials, URLs or run programs.
# _gha_check_config_value <key=value>
_gha_check_config_value() {
    local k
    k="$(_gha_lower "${1%%=*}")"
    case "$k" in
        credential.* | url.* | http.* | core.askpass | core.sshcommand | core.gitproxy | \
            core.hookspath | core.fsmonitor | core.pager | core.editor | include.* | \
            includeif.* | alias.* | protocol.* | filter.* | remote.*.url | remote.*.pushurl | \
            remote.*.proxy | remote.*.uploadpack | remote.*.receivepack | remote.*.vcs)
            _gha_fail 2 "Configuration key '${1%%=*}' is not allowed in clone -c/--config." \
                "It could expose the installation token or run an external program."
            ;;
    esac
}

# Split arguments into git options (_GHA_OPTS) and positionals (_GHA_POS).
# _gha_parse_git_args <action> <args...>
_gha_parse_git_args() {
    local action="$1" a name valopts
    shift
    _GHA_POS=()
    _GHA_OPTS=()
    valopts="$(_gha_value_options "$action")"

    while [[ $# -gt 0 ]]; do
        a="$1"
        if [[ "$a" == "--" ]]; then
            shift
            while [[ $# -gt 0 ]]; do _GHA_POS+=("$1"); shift; done
            break
        elif [[ "$a" == -?* ]]; then
            name="${a%%=*}"
            _gha_deny_option "$action" "$name"
            if [[ "$action" == "clone" ]]; then
                # -c key=value, --config=key=value and abbreviations of --config
                if [[ "$a" == -c?* && "$a" != --* ]]; then
                    _gha_check_config_value "${a#-c}"
                elif [[ "$name" == "--config="* ]]; then
                    :
                elif [[ "$a" == --?*=* && "--config" == "$name"* ]]; then
                    _gha_check_config_value "${a#*=}"
                fi
            fi
            _GHA_OPTS+=("$a")
            shift
            if [[ "$a" != *=* && "$valopts" == *" $name "* ]]; then
                [[ $# -gt 0 ]] || _gha_fail 2 "Option $name requires a value."
                if [[ "$action" == "clone" && ( "$name" == "-c" || ( "$name" == --?* && "--config" == "$name"* ) ) ]]; then
                    _gha_check_config_value "$1"
                fi
                _GHA_OPTS+=("$1")
                shift
            fi
        else
            _GHA_POS+=("$a")
            shift
        fi
    done
}

# True when any pass-through option equals one of the given names.
_gha_has_opt() {
    local i o want
    for ((i = 0; i < ${#_GHA_OPTS[@]}; i++)); do
        o="${_GHA_OPTS[i]}"
        o="${o%%=*}"
        for want in "$@"; do
            if [[ "$o" == "$want" ]]; then return 0; fi
        done
    done
    return 1
}

# --------------------------------------------------------------------------
# Cleanup and git execution
# --------------------------------------------------------------------------
_gha_cleanup() {
    local rc=$?
    trap - EXIT

    # Revoke the installation token as soon as this operation ends, unless it
    # belongs to an enclosing session (the session owner revokes it).
    if [[ -n "$_GHA_TOKEN" && "$_GHA_SESSION_REUSED" != "1" && "$_GHA_KEEP_TOKEN" != "1" ]]; then
        local code
        code="$(_gha_curl_with_bearer "$_GHA_TOKEN" \
            --silent --show-error \
            --connect-timeout 10 --max-time 30 \
            --output /dev/null --write-out '%{http_code}' \
            --request DELETE "${_GHA_API_BASE}/installation/token" \
            --header "Accept: application/vnd.github+json" 2>/dev/null || true)"
        if [[ "$code" == "204" ]]; then
            _gha_log info "Installation token revoked"
        else
            _gha_log warn "Token revocation returned HTTP ${code:-no response}; it expires within 1 hour"
        fi
    fi

    if [[ -n "$_GHA_TMP_DIR" && -d "$_GHA_TMP_DIR" ]]; then rm -rf "$_GHA_TMP_DIR"; fi
    _GHA_TOKEN=""
    _GHA_JWT=""
    exit "$rc"
}

_gha_configure_identity() {
    local repo_dir="$1"
    if [[ -n "$GIT_USER_NAME" && -n "$GIT_USER_EMAIL" ]]; then
        if [[ ! -d "$repo_dir" ]]; then
            _gha_log warn "Cannot set commit identity: directory not found: $repo_dir"
            return 0
        fi
        git -C "$repo_dir" config --local user.name "$GIT_USER_NAME"
        git -C "$repo_dir" config --local user.email "$GIT_USER_EMAIL"
        _gha_log info "Configured local commit identity: $GIT_USER_NAME <$GIT_USER_EMAIL>"
    fi
}

# The token is handed only to this git process, through GIT_ASKPASS.
# It is never placed in a URL, git config, credential store or command line.
_gha_git() {
    local gh_host_nohash="${GH_HOST#https://}"
    GH_APP_TOKEN="$_GHA_TOKEN" \
    GH_APP_HOST="$gh_host_nohash" \
    GIT_TERMINAL_PROMPT=0 \
    GIT_ASKPASS="$_GHA_ASKPASS" \
    GIT_ASKPASS_REQUIRE=force \
        git -c credential.helper= \
            -c "url.https://${gh_host_nohash}/.insteadOf=git@${gh_host_nohash}:" \
            "$@"
}

_gha_write_askpass() {
    _GHA_ASKPASS="${_GHA_TMP_DIR}/askpass.sh"
    cat > "$_GHA_ASKPASS" <<'ASKPASS_EOF'
#!/bin/sh
# Answer only for the configured GitHub host. Git may contact other hosts
# (submodules, HTTP redirects); the token must never be sent to them.
h="${1#*\'}"; h="${h%%\'*}"
h="${h#*://}"; h="${h##*@}"; h="${h%%/*}"
h="$(printf '%s' "$h" | tr '[:upper:]' '[:lower:]')"
w="$(printf '%s' "$GH_APP_HOST" | tr '[:upper:]' '[:lower:]')"
[ -n "$h" ] && [ "$h" = "$w" ] || exit 1
case "$1" in
    *Username*) printf '%s\n' 'x-access-token' ;;
    *Password*) printf '%s\n' "$GH_APP_TOKEN" ;;
    *) exit 1 ;;
esac
ASKPASS_EOF
    chmod 700 "$_GHA_ASKPASS"
}

# Repository URL from an explicit https URL, or from a remote of the current
# working tree (default: origin). Prints nothing when it cannot be determined.
_gha_detect_repo_url() {
    local target="${1:-}" top url=""
    if [[ "$target" == https://* ]]; then
        url="$target"
    elif top="$(git rev-parse --show-toplevel 2>/dev/null)"; then
        url="$(git -C "$top" remote get-url "${target:-origin}" 2>/dev/null)" || url=""
    fi
    printf '%s' "$url"
}

# --------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------
git_app() {
    # Never let shell tracing leak tokens.
    case "$-" in *x*) set +x ;; esac

    local action=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose) _GHA_CLI_LEVEL="debug"; shift ;;
            --quiet) _GHA_CLI_LEVEL="warn"; shift ;;
            --dry-run) _GHA_DRY_RUN=1; shift ;;
            --profile)
                [[ $# -ge 2 ]] || _gha_fail 2 "--profile requires a name"
                _GHA_CLI_PROFILE="$2"; shift 2 ;;
            --profile=*) _GHA_CLI_PROFILE="${1#--profile=}"; shift ;;
            --config)
                [[ $# -ge 2 ]] || _gha_fail 2 "--config requires a file"
                _GHA_CONFIG_FILE="$2"; shift 2 ;;
            --config=*) _GHA_CONFIG_FILE="${1#--config=}"; shift ;;
            -h | --help | help) git_app_usage; return 0 ;;
            -V | --version | version) git_app_version; return 0 ;;
            -*)
                git_app_usage >&2
                _gha_fail 2 "Unknown option: $1" ;;
            *) action="$1"; shift; break ;;
        esac
    done
    if [[ -z "$action" ]]; then git_app_usage; return 0; fi

    case "$action" in
        clone | add | commit | fetch | pull | push | check | session | token | revoke | config) ;;
        *)
            git_app_usage >&2
            _gha_fail 2 "Unknown action: $action" ;;
    esac

    _gha_load_config

    if [[ -n "$GIT_USER_NAME" || -n "$GIT_USER_EMAIL" ]]; then
        [[ -n "$GIT_USER_NAME" && -n "$GIT_USER_EMAIL" ]] ||
            _gha_fail 2 "Set both GIT_USER_NAME and GIT_USER_EMAIL, or leave both unset."
    fi

    local repo_dir=""
    case "$action" in
        config)
            case "${1:-}" in
                "" | show)
                    printf 'Profile: %s\n' "${_GHA_PROFILE:-(none)}"
                    _gha_config_show ;;
                init) _gha_config_init ;;
                profiles) _gha_config_profiles ;;
                *) _gha_fail 2 "Usage: rk git-app config [show|init|profiles]" ;;
            esac
            return 0
            ;;
        revoke)
            # Revoke a token previously printed by `git-app token`. Only the host
            # is needed; the token comes from $GH_APP_TOKEN or the first stdin line.
            [[ $# -eq 0 ]] || _gha_fail 2 "Usage: rk git-app revoke   (token in \$GH_APP_TOKEN or on stdin)"
            _gha_require_commands curl
            [[ -n "$GH_HOST" ]] || _gha_fail 2 "Missing required configuration: GH_HOST" \
                "Set GH_HOST or a config file ($(_gha_user_config_path))."
            _gha_configure_api_base
            _GHA_TOKEN="${GH_APP_TOKEN:-}"
            if [[ -z "$_GHA_TOKEN" && ! -t 0 ]]; then IFS= read -r _GHA_TOKEN || true; fi
            [[ -n "$_GHA_TOKEN" ]] || _gha_fail 2 "No token to revoke." \
                "Set GH_APP_TOKEN or pipe the token on stdin."
            [[ "$_GHA_TOKEN" =~ ^[A-Za-z0-9_.-]+$ ]] || { _GHA_TOKEN=""; _gha_fail 2 "The token has an unexpected format."; }
            if [[ "$_GHA_DRY_RUN" == "1" ]]; then
                _gha_log info "DRY RUN: would revoke the token (DELETE ${_GHA_API_BASE}/installation/token)"
                _GHA_TOKEN=""
                return 0
            fi
            local rcode
            rcode="$(_gha_curl_with_bearer "$_GHA_TOKEN" \
                --silent --show-error \
                --connect-timeout 10 --max-time 30 \
                --output /dev/null --write-out '%{http_code}' \
                --request DELETE "${_GHA_API_BASE}/installation/token" \
                --header "Accept: application/vnd.github+json" 2>/dev/null || true)"
            _GHA_TOKEN=""
            case "$rcode" in
                204) _gha_log info "Installation token revoked"; return 0 ;;
                401) _gha_fail 3 "Token already expired or revoked (HTTP 401)." ;;
                *) _gha_fail 3 "Token revocation failed (HTTP ${rcode:-no response})." ;;
            esac
            ;;
        add)
            repo_dir="$(git rev-parse --show-toplevel 2>/dev/null)" ||
                _gha_fail 2 "Run 'rk git-app add' from inside a Git working tree."
            if [[ "$_GHA_DRY_RUN" == "1" ]]; then
                _gha_log info "DRY RUN: git add --dry-run (nothing is staged)"
                if [[ "$#" -gt 0 ]]; then
                    git -C "$repo_dir" add --dry-run -- "$@"
                else
                    git -C "$repo_dir" add --dry-run -A
                fi
                return 0
            fi
            _gha_configure_identity "$repo_dir"
            if [[ "$#" -gt 0 ]]; then
                git -C "$repo_dir" add -- "$@"
            else
                git -C "$repo_dir" add -A
            fi
            _gha_log info "Changes staged successfully"
            return 0
            ;;
        commit)
            repo_dir="$(git rev-parse --show-toplevel 2>/dev/null)" ||
                _gha_fail 2 "Run 'rk git-app commit' from inside a Git working tree."
            [[ "$#" -gt 0 ]] ||
                _gha_fail 2 "Usage: rk git-app commit \"commit message\" (or: commit -m \"commit message\")"
            if [[ "$_GHA_DRY_RUN" == "1" ]]; then
                _gha_log info "DRY RUN: git commit --dry-run (nothing is committed)"
                if [[ "$1" == -* ]]; then
                    git -C "$repo_dir" commit --dry-run "$@" || true
                else
                    git -C "$repo_dir" commit --dry-run -m "$*" || true
                fi
                return 0
            fi
            _gha_configure_identity "$repo_dir"
            if [[ "$1" == -* ]]; then
                git -C "$repo_dir" commit "$@"
            else
                git -C "$repo_dir" commit -m "$*"
            fi
            _gha_log info "Commit created successfully"
            return 0
            ;;
    esac

    # ---- Network operations (clone/fetch/pull/push/check/session) ----
    _gha_require_commands openssl curl jq
    _gha_require_remote_config

    trap _gha_cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'exit 129' HUP

    _GHA_TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gh-app-git.XXXXXX")" ||
        _gha_fail 1 "Could not create temporary directory."
    chmod 700 "$_GHA_TMP_DIR"

    local remote="origin" repo_url="" destination="" perm="read" target="" n i
    local -a refspecs=()
    local -a session_cmd=()
    _GHA_CMD=()

    case "$action" in
        clone)
            _gha_parse_git_args clone "$@"
            n=${#_GHA_POS[@]}
            [[ $n -ge 1 ]] || _gha_fail 2 "Usage: rk git-app clone [git-clone options] <https-repo-url> [directory]"
            [[ $n -le 2 ]] || _gha_fail 2 "Too many arguments for clone: ${_GHA_POS[2]}"
            repo_url="${_GHA_POS[0]}"
            destination="${_GHA_POS[1]:-}"
            [[ "$repo_url" == https://* ]] || _gha_fail 2 "Repository URL must use HTTPS."
            _gha_parse_repo_url "$repo_url"
            _GHA_CMD=(clone ${_GHA_OPTS[@]+"${_GHA_OPTS[@]}"} -- "$repo_url")
            if [[ -n "$destination" ]]; then _GHA_CMD+=("$destination"); fi
            ;;
        fetch | pull | push)
            repo_dir="$(git rev-parse --show-toplevel 2>/dev/null)" ||
                _gha_fail 2 "Run 'rk git-app $action' from inside the Git working tree."
            _gha_parse_git_args "$action" "$@"
            n=${#_GHA_POS[@]}

            if [[ "$action" == "fetch" ]] && _gha_has_opt --all; then
                if [[ $n -gt 0 ]]; then
                    _gha_fail 2 "fetch --all does not take a repository argument: ${_GHA_POS[0]}"
                fi
                # For fetch --all across multiple remotes, mint an installation-wide token
                _GHA_REPO_OWNER=""
                _GHA_REPO_NAME=""
                _GHA_CMD=(-C "$repo_dir" "$action" ${_GHA_OPTS[@]+"${_GHA_OPTS[@]}"})
            else
                remote="${_GHA_POS[0]:-origin}"
                for ((i = 1; i < n; i++)); do refspecs+=("${_GHA_POS[i]}"); done

                if [[ "$action" == "push" ]]; then
                    repo_url="$(git -C "$repo_dir" remote get-url --push "$remote" 2>/dev/null)" ||
                        _gha_fail 2 "Git remote '$remote' is not configured in this repository."
                    perm="write"
                else
                    repo_url="$(git -C "$repo_dir" remote get-url "$remote" 2>/dev/null)" ||
                        _gha_fail 2 "Git remote '$remote' is not configured in this repository."
                fi
                [[ "$repo_url" == https://* ]] ||
                    _gha_fail 2 "Remote '$remote' must use HTTPS for GitHub App token authentication."
                _gha_parse_repo_url "$repo_url"

                if [[ ${#refspecs[@]} -eq 0 ]]; then
                    if [[ "$action" == "push" ]] && _gha_has_opt --delete -d; then
                        _gha_fail 2 "push --delete needs an explicit branch." \
                            "e.g. rk git-app push --delete $remote old-branch"
                    elif [[ "$action" == "push" ]] && _gha_has_opt --tags --all --mirror; then
                        : # these push sets of refs; do not add the current branch
                    elif [[ "$action" == "pull" || "$action" == "push" ]]; then
                        local cur_branch
                        cur_branch="$(git -C "$repo_dir" symbolic-ref --quiet --short HEAD)" ||
                            _gha_fail 2 "Cannot determine the current branch." \
                                "Supply a branch, e.g. 'rk git-app $action $remote main'."
                        refspecs+=("$cur_branch")
                    fi
                fi
                _GHA_CMD=(-C "$repo_dir" "$action" ${_GHA_OPTS[@]+"${_GHA_OPTS[@]}"} "$remote"
                    ${refspecs[@]+"${refspecs[@]}"})
            fi
            ;;
        check)
            [[ $# -le 1 ]] || _gha_fail 2 "Usage: rk git-app check [repo-url | remote]"
            target="${1:-}"
            repo_url="$(_gha_detect_repo_url "$target")"
            if [[ "$target" != https://* && -n "$repo_url" && "$repo_url" != "$GH_HOST/"* ]]; then
                # Auto-detected remote is on another host: validate the App only.
                _gha_log warn "Remote is not on $GH_HOST; skipping repository check"
                repo_url=""
            fi
            if [[ -n "$repo_url" ]]; then _gha_parse_repo_url "$repo_url"; fi
            ;;
        session | token)
            local all_repos=0
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --write) perm="write"; shift ;;
                    --all-repos) all_repos=1; shift ;;
                    --repo)
                        [[ $# -ge 2 ]] || _gha_fail 2 "--repo requires a URL or remote name"
                        target="$2"; shift 2 ;;
                    --repo=*) target="${1#--repo=}"; shift ;;
                    --)
                        [[ "$action" == "session" ]] ||
                            _gha_fail 2 "'token' does not run a command." "Use: TOKEN=\$(rk git-app token [--all-repos | --repo <url>])"
                        shift
                        while [[ $# -gt 0 ]]; do session_cmd+=("$1"); shift; done
                        ;;
                    *)
                        _gha_fail 2 "Unknown $action argument: $1" \
                            "Usage: rk git-app $action [--write] [--all-repos | --repo <url|remote>]$([[ "$action" == "session" ]] && printf ' [-- command [args...]]')" ;;
                esac
            done
            if [[ "$all_repos" == "1" && -n "$target" ]]; then
                _gha_fail 2 "Cannot combine --all-repos and --repo."
            fi
            if [[ "$all_repos" == "0" ]]; then
                repo_url="$(_gha_detect_repo_url "$target")"
                [[ -n "$repo_url" ]] || _gha_fail 2 "Cannot determine the repository for the $action." \
                    "Run inside a working tree with an HTTPS remote, pass --repo <url|remote>, or use --all-repos."
                _gha_parse_repo_url "$repo_url"
            fi
            if [[ -n "${GIT_APP_SESSION_TOKEN:-}" ]]; then
                _gha_fail 2 "Already inside a git-app session." \
                    "Run git-app actions directly; they reuse the session token. Exit the session first to start another."
            fi
            ;;
    esac

    _gha_log info "Configuration OK (host: $GH_HOST${_GHA_PROFILE:+, profile: $_GHA_PROFILE}, key: $GH_PRIVATE_KEY)"

    # ---- Dry run: local validation only, then describe what would happen ----
    if [[ "$_GHA_DRY_RUN" == "1" ]]; then
        _gha_check_private_key
        _gha_make_jwt
        _GHA_JWT=""
        _gha_log info "DRY RUN: no network requests are made and no token is minted"
        _gha_log info "Local checks passed: configuration, private key, JWT signing"
        if [[ "$action" == "check" ]]; then
            _gha_log info "Would verify: App (GET /app), installation $GH_INSTALLATION_ID${_GHA_REPO_NAME:+, repository ${_GHA_REPO_OWNER}/${_GHA_REPO_NAME}}"
        elif [[ -n "$_GHA_REPO_NAME" ]]; then
            _gha_log info "Would verify installation $GH_INSTALLATION_ID and mint a token (contents: $perm) for ${_GHA_REPO_OWNER}/${_GHA_REPO_NAME} on $GH_HOST"
        else
            _gha_log info "Would verify installation $GH_INSTALLATION_ID and mint a token (contents: $perm) for all installation repositories on $GH_HOST"
        fi
        if [[ ${#_GHA_CMD[@]} -gt 0 ]]; then
            _gha_log info "Would run: git -c credential.helper= $(_gha_quote_cmd "${_GHA_CMD[@]}")"
        fi
        if [[ "$action" == "token" ]]; then
            _gha_log info "Would print the token on stdout and leave it valid until it expires (not revoked)"
        fi
        if [[ "$action" == "session" ]]; then
            if [[ ${#session_cmd[@]} -gt 0 ]]; then
                _gha_log info "Would run in session: $(_gha_quote_cmd "${session_cmd[@]}")"
            else
                _gha_log info "Would start an interactive shell with the session token"
            fi
        fi
        return 0
    fi

    # ---- check: validate App, installation and (optionally) repository ----
    if [[ "$action" == "check" ]]; then
        _gha_check_private_key
        _gha_make_jwt
        _gha_validate_app
        _gha_validate_installation
        if [[ -n "$_GHA_REPO_NAME" ]]; then
            _gha_mint_token read
            _gha_validate_repo read
        else
            _gha_log info "No repository given or detected; skipped repository access check"
        fi
        _gha_log info "All checks passed"
        return 0
    fi

    # ---- token: print ONE token on stdout and leave it valid (no revocation) ----
    if [[ "$action" == "token" ]]; then
        # If validation fails after minting, the EXIT trap still revokes the token;
        # it is kept only once everything succeeded.
        _gha_mint_and_validate "$perm"
        _GHA_KEEP_TOKEN=1
        if [[ -t 1 ]]; then
            _gha_log warn "stdout is a terminal: the token is printed in clear text. Use TOKEN=\$(rk git-app token ...)"
        fi
        if [[ -n "$_GHA_REPO_NAME" ]]; then
            _gha_log info "Token issued for ${_GHA_REPO_OWNER}/${_GHA_REPO_NAME} (contents: $perm), valid until ${_GHA_TOKEN_EXPIRES:-about 1 hour from now}. Not revoked; run 'rk git-app revoke' to revoke early."
        else
            _gha_log info "Token issued for all installation repositories (contents: $perm), valid until ${_GHA_TOKEN_EXPIRES:-about 1 hour from now}. Not revoked; run 'rk git-app revoke' to revoke early."
        fi
        printf '%s\n' "$_GHA_TOKEN"
        return 0
    fi

    # ---- session: one token, one repository, revoked when the command ends ----
    if [[ "$action" == "session" ]]; then
        local src=0 expires
        _gha_mint_and_validate "$perm"
        expires=$(($(date +%s) + 3300))   # tokens last 1h; stay conservative
        if [[ ${#session_cmd[@]} -eq 0 ]]; then
            local shell_path="${SHELL:-/bin/sh}"
            [[ -x "$shell_path" ]] || shell_path="/bin/sh"
            session_cmd=("$shell_path" -i)
            _gha_log info "Session started for ${_GHA_REPO_OWNER}/${_GHA_REPO_NAME} (contents: $perm). Exit the shell to revoke the token."
        fi
        # Ctrl-C belongs to the session command; a no-op trap (not "ignore") is
        # reset to default in the child, so the child still receives SIGINT.
        trap ':' INT
        (
            export GIT_APP_SESSION_TOKEN="$_GHA_TOKEN"
            export GIT_APP_SESSION_REPO="${_GHA_REPO_NAME:+"${_GHA_REPO_OWNER}/${_GHA_REPO_NAME}"}"
            export GIT_APP_SESSION_REPO="${GIT_APP_SESSION_REPO:-*}"
            export GIT_APP_SESSION_HOST="$GH_HOST"
            export GIT_APP_SESSION_PERM="$perm"
            export GIT_APP_SESSION_EXPIRES="$expires"
            exec "${session_cmd[@]}"
        ) || src=$?
        exit "$src"
    fi

    # ---- clone/fetch/pull/push: token (session or fresh), then run git ----
    if ! _gha_session_reuse "$perm"; then
        _gha_mint_and_validate "$perm"
    fi
    _gha_write_askpass

    case "$action" in
        clone)
            _gha_log info "Cloning $repo_url"
            _gha_git "${_GHA_CMD[@]}"
            _gha_configure_identity "${destination:-$_GHA_REPO_NAME}"
            ;;
        fetch)
            _gha_configure_identity "$repo_dir"
            _gha_log info "Fetching from remote $remote"
            _gha_git "${_GHA_CMD[@]}"
            ;;
        pull)
            _gha_configure_identity "$repo_dir"
            _gha_log info "Pulling from remote $remote"
            _gha_git "${_GHA_CMD[@]}"
            ;;
        push)
            _gha_configure_identity "$repo_dir"
            _gha_log info "Pushing to remote $remote"
            _gha_git "${_GHA_CMD[@]}"
            ;;
    esac

    _gha_log info "Git operation completed successfully"
}
