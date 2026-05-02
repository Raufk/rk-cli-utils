#!/usr/bin/env bash
# Function to get Slack User ID from email
get_slack_user_id() {
    local email="$1"
    local slack_token="$2"
    local response ok slack_id

    [[ -z "$email" ]] && { echo "email required" >&2; return 2; }
    [[ -z "$slack_token" ]] && { echo "missing slack token" >&2; return 2; }

    response=$(curl -sS -X POST \
        -H "Authorization: Bearer ${slack_token}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "email=${email}" \
        https://slack.com/api/users.lookupByEmail) || {
            echo "curl request failed" >&2
            return 3
        }

    ok=$(jq -r '.ok' <<< "$response")

    [[ "$ok" != "true" ]] && {
        jq -r '.error // "unknown error"' <<< "$response" >&2
        return 1
    }

    slack_id=$(jq -r '.user.id' <<< "$response")
    echo "$slack_id"
}

# Function to construct Slack message payload with attachments
construct_slack_payload() {
    local channel="$1"
    local color="$2"
    local message="$3"

    # Initialize the payload
    local payload="{\"channel\":\"$channel\",\"attachments\":["

    # Process message to split on "~"
    # IFS=$'\n' read -r -d '' -a sections <<<"$(echo -e "$message")"
    if [[ $message =~ .*~.* ]]; then
        IFS='~' read -r -a sections <<< "$message"
    else
        sections=("$message")
    fi

    # Iterate over sections to create attachments
    for section in "${sections[@]}"; do
        # Clean and escape the section text
        local escaped_section=$(echo "$section" | sed 's/"/\\"/g')
        payload+="{\"color\":\"$color\",\"text\":\"$escaped_section\"},"
    done

    # Finalize the payload
    payload="${payload%,}]}"

    echo "$payload"
}

# Function to send a message to Slack
slack_send() {
    local slack_color="$1"
    local slack_channels="$2"
    local slack_message="$3"
    local slack_token="$4"

    # Validation
    [[ -z "$slack_token" ]] && { echo "missing slack token" >&2; return 2; }
    [[ -z "$slack_channels" ]] && { echo "missing channel" >&2; return 2; }
    [[ -z "$slack_message" ]] && { echo "missing message" >&2; return 2; }
    [[ -z "$slack_color" ]] && slack_color="good" # Optional: default color

    local -a channelList
    IFS=',' read -r -a channelList <<< "$slack_channels"

    for channel in "${channelList[@]}"; do
        local payload response ok error
        # Define the JSON payload
        # payload="{\"channel\":\"$channel\",\"text\":\"\",\"attachments\":[{\"color\":\"$SLACK_COLOR\",\"text\":\"$SLACK_MESSAGE\"}]}"
        payload=$(construct_slack_payload "$channel" "$slack_color" "$slack_message")
        # Send the message to Slack
        response=$(curl -sS -X POST \
        -H "Authorization: Bearer $slack_token" \
        -H "Content-Type: application/json; charset=utf-8" \
        -d "$payload" \
        https://slack.com/api/chat.postMessage) || {
            echo "curl failed for channel $channel" >&2
            continue
        }

        ok=$(jq -r '.ok' <<< "$response")
        error=$(jq -r '.error // empty' <<< "$response")

        if [[ "$ok" != "true" ]]; then
        echo "❌ Slack message failed for $channel: ${error:-unknown}" >&2
        echo "$response" >&2
        fi
        echo "Slack message successfully sent to $channel"
    done
}