#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# ==================== Configuration ====================
SMTP_URL="${MAIL_SMTP_URL:-}"
USERNAME="${MAIL_USERNAME:-}"
PASSWORD="${MAIL_PASSWORD:-}"
MAIL_FROM="${MAIL_FROM:-}"
MAIL_TO="${MAIL_TO:-}"
SUBJECT="${MAIL_SUBJECT:-}"

TEXT_BODY="${MAIL_TEXT_BODY:-}"
TEXT_BODY_FILE="${MAIL_TEXT_BODY_FILE:-}"
HTML_BODY="${MAIL_HTML_BODY:-}"
HTML_BODY_FILE="${MAIL_HTML_BODY_FILE:-}"
# ==================================================

# Define cleanup function to ensure temporary file is always deleted
cleanup() {
    if [[ -n "${MAIL_FILE:-}" && -f "$MAIL_FILE" ]]; then
        rm -f "$MAIL_FILE"
    fi
}

# Trap EXIT, SIGHUP, SIGINT, SIGTERM to run cleanup
trap cleanup EXIT SIGHUP SIGINT SIGTERM

# Initialize temporary file
MAIL_FILE=$(mktemp)

# Validate required variables
MISSING_VARS=()
[[ -z "$SMTP_URL" ]] && MISSING_VARS+=("MAIL_SMTP_URL")
[[ -z "$USERNAME" ]] && MISSING_VARS+=("MAIL_USERNAME")
[[ -z "$PASSWORD" ]] && MISSING_VARS+=("MAIL_PASSWORD")
[[ -z "$MAIL_FROM" ]] && MISSING_VARS+=("MAIL_FROM")
[[ -z "$MAIL_TO" ]] && MISSING_VARS+=("MAIL_TO")
[[ -z "$SUBJECT" ]] && MISSING_VARS+=("MAIL_SUBJECT")

if (( ${#MISSING_VARS[@]} > 0 )); then
    echo "Error: Missing required environment variables: ${MISSING_VARS[*]}" >&2
    exit 1
fi

# Helper function to extract clean email address from "Display Name <email@example.com>" or "email@example.com"
extract_email() {
    local input="$1"
    if [[ "$input" =~ \<([^>]+)\> ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "$input" | xargs
    fi
}

# Helper function to unconditionally encode a header string per RFC 2047 (=?UTF-8?B?...?=)
encode_rfc2047() {
    local input="$1"
    local b64
    b64=$(printf "%s" "$input" | base64 | tr -d '\r\n')
    echo "=?UTF-8?B?${b64}?="
}

ENVELOPE_FROM=$(extract_email "$MAIL_FROM")

# Format From header with RFC 2047 encoding for display name if present
if [[ "$MAIL_FROM" =~ ^(.*)\<([^>]+)\>$ ]]; then
    DISPLAY_NAME=$(echo "${BASH_REMATCH[1]}" | xargs)
    CLEAN_ADDR="${BASH_REMATCH[2]}"
    if [[ -n "$DISPLAY_NAME" ]]; then
        ENCODED_NAME=$(encode_rfc2047 "$DISPLAY_NAME")
        MAIL_FROM_HEADER="${ENCODED_NAME} <${CLEAN_ADDR}>"
    else
        MAIL_FROM_HEADER="<${CLEAN_ADDR}>"
    fi
else
    MAIL_FROM_HEADER="$MAIL_FROM"
fi

ENCODED_SUBJECT=$(encode_rfc2047 "$SUBJECT")

# Parse comma-separated MAIL_TO list into --mail-rcpt argument array and formatted MIME To header
MAIL_RCPT_ARGS=()
TO_HEADER_PARTS=()
IFS=',' read -ra ADDR_ARRAY <<< "$MAIL_TO"
for addr in "${ADDR_ARRAY[@]}"; do
    addr_trimmed=$(echo "$addr" | xargs)
    clean_addr=$(extract_email "$addr_trimmed")
    if [[ -n "$clean_addr" ]]; then
        MAIL_RCPT_ARGS+=("--mail-rcpt" "$clean_addr")

        if [[ "$addr_trimmed" =~ ^(.*)\<([^>]+)\>$ ]]; then
            display_name=$(echo "${BASH_REMATCH[1]}" | xargs)
            if [[ -n "$display_name" ]]; then
                encoded_name=$(encode_rfc2047 "$display_name")
                TO_HEADER_PARTS+=("${encoded_name} <${clean_addr}>")
            else
                TO_HEADER_PARTS+=("<${clean_addr}>")
            fi
        else
            TO_HEADER_PARTS+=("$clean_addr")
        fi
    fi
done

if (( ${#MAIL_RCPT_ARGS[@]} == 0 )); then
    echo "Error: No valid recipient email address found in MAIL_TO." >&2
    exit 1
fi

# Join recipient parts with commas for the MIME To header
TO_HEADER_STR=$(IFS=', '; echo "${TO_HEADER_PARTS[*]}")

# Resolve text body content (file priority over raw text string)
TEXT_CONTENT=""
if [[ -n "$TEXT_BODY_FILE" ]]; then
    if [[ -f "$TEXT_BODY_FILE" ]]; then
        TEXT_CONTENT=$(<"$TEXT_BODY_FILE")
    else
        echo "Error: Text body file not found: $TEXT_BODY_FILE" >&2
        exit 1
    fi
elif [[ -n "$TEXT_BODY" ]]; then
    TEXT_CONTENT="$TEXT_BODY"
fi

# Resolve HTML body content (file priority over raw HTML string)
HTML_CONTENT=""
if [[ -n "$HTML_BODY_FILE" ]]; then
    if [[ -f "$HTML_BODY_FILE" ]]; then
        HTML_CONTENT=$(<"$HTML_BODY_FILE")
    else
        echo "Error: HTML body file not found: $HTML_BODY_FILE" >&2
        exit 1
    fi
elif [[ -n "$HTML_BODY" ]]; then
    HTML_CONTENT="$HTML_BODY"
fi

# Validate that at least one body option is provided
if [[ -z "$TEXT_CONTENT" && -z "$HTML_CONTENT" ]]; then
    echo "Error: Both text and HTML body are empty. Please provide body or body_file." >&2
    exit 1
fi

echo "==> Generating email MIME structure..."

BOUNDARY="mail-boundary-$(date +%s%N)"

# 1. Write email headers
cat <<EOF > "$MAIL_FILE"
From: $MAIL_FROM_HEADER
To: $TO_HEADER_STR
Subject: $ENCODED_SUBJECT
MIME-Version: 1.0
EOF

# 2. Determine MIME type structure based on available content
if [[ -n "$TEXT_CONTENT" && -n "$HTML_CONTENT" ]]; then
    # Both are provided: use multipart/alternative
    echo "Content-Type: multipart/alternative; boundary=\"$BOUNDARY\"" >> "$MAIL_FILE"
    echo "" >> "$MAIL_FILE"

    # Append Text Part
    echo "--$BOUNDARY" >> "$MAIL_FILE"
    echo 'Content-Type: text/plain; charset="utf-8"' >> "$MAIL_FILE"
    echo "Content-Transfer-Encoding: base64" >> "$MAIL_FILE"
    echo "" >> "$MAIL_FILE"
    printf "%s" "$TEXT_CONTENT" | base64 >> "$MAIL_FILE"
    echo "" >> "$MAIL_FILE"

    # Append HTML Part
    echo "--$BOUNDARY" >> "$MAIL_FILE"
    echo 'Content-Type: text/html; charset="utf-8"' >> "$MAIL_FILE"
    echo "Content-Transfer-Encoding: base64" >> "$MAIL_FILE"
    echo "" >> "$MAIL_FILE"
    printf "%s" "$HTML_CONTENT" | base64 >> "$MAIL_FILE"
    echo "" >> "$MAIL_FILE"

    # Close boundary
    echo "--$BOUNDARY--" >> "$MAIL_FILE"

elif [[ -n "$TEXT_CONTENT" ]]; then
    # Only Text is provided
    echo 'Content-Type: text/plain; charset="utf-8"' >> "$MAIL_FILE"
    echo "Content-Transfer-Encoding: base64" >> "$MAIL_FILE"
    echo "" >> "$MAIL_FILE"
    printf "%s" "$TEXT_CONTENT" | base64 >> "$MAIL_FILE"

else
    # Only HTML is provided
    echo 'Content-Type: text/html; charset="utf-8"' >> "$MAIL_FILE"
    echo "Content-Transfer-Encoding: base64" >> "$MAIL_FILE"
    echo "" >> "$MAIL_FILE"
    printf "%s" "$HTML_CONTENT" | base64 >> "$MAIL_FILE"
fi

echo "==> Sending email via curl to $MAIL_TO..."

# 3. Send via curl and check exit status
set +e
curl --fail --show-error \
  --url "$SMTP_URL" \
  --user "$USERNAME:$PASSWORD" \
  --mail-from "$ENVELOPE_FROM" \
  "${MAIL_RCPT_ARGS[@]}" \
  --upload-file "$MAIL_FILE"
CURL_EXIT_CODE=$?
set -e

if (( CURL_EXIT_CODE != 0 )); then
    echo "Error: Failed to send email via curl (exit code: $CURL_EXIT_CODE)." >&2
    exit "$CURL_EXIT_CODE"
fi

echo "==> Email sent successfully!"
