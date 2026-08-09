# Development Log & Technical Pitfalls

This log documents the design decisions, security considerations, and technical pitfalls resolved during the development of `sendmail-action`.

---

## 0. Architecture & Security: Zero Third-Party Dependencies

### Design Decision
Instead of building a Node.js or Docker-based GitHub Action, `sendmail-action` is built purely with system-native `bash` and `curl`.

### Security Advantage
- **Mitigates Supply Chain Attacks**: Modern CI/CD pipelines are increasingly targeted by supply chain attacks (e.g., compromised NPM packages or malicious third-party dependencies). By relying solely on OS-installed binaries (`curl`, `bash`, `base64`), this action eliminates external dependency trees entirely.
- **Native GitHub CLI in Workflows**: Even for repository releases, we avoid third-party release actions (such as `softprops/action-gh-release`) and instead use GitHub's pre-installed `gh` CLI (`gh release create "${GITHUB_REF_NAME}" --generate-notes`) powered directly by `GH_TOKEN`.
- **Maximum Reliability**: Eliminates runtime version mismatches (Node.js versions, breaking npm updates) across Linux/macOS runners.

---

## 1. Non-ASCII Characters in Mail Headers (`no subject` Issue)

### Issue
When sending emails with non-ASCII characters in headers (such as Chinese characters in the `Subject:` line or `From:` display name), recipient mail clients or SMTP relays (e.g., Gmail, Google Groups, Outlook) failed to parse the header. Consequently, the email was displayed as **`(no subject)`** or with corrupted headers.

### Root Cause
RFC 5322 stipulates that email headers must contain only **7-bit ASCII** characters. Placing raw UTF-8 bytes directly into header fields violates standard MIME specs.

### Solution (RFC 2047 Encoded-Word)
We apply RFC 2047 Base64 encoding to header fields containing non-ASCII text or unconditionally encode `Subject` / `Display Name`:

```text
Subject: =?UTF-8?B?<base64_string>?=
```

In `send-mail.sh`, this is implemented via:

```bash
encode_rfc2047() {
    local input="$1"
    local b64
    b64=$(printf "%s" "$input" | base64 | tr -d '\r\n')
    echo "=?UTF-8?B?${b64}?="
}
```

---

## 2. SMTP Envelope (`--mail-rcpt`) vs MIME Header (`To:` / `From:`)

### Issue
Passing a Display Name string like `Sender Name <user@example.com>` directly to `curl --mail-rcpt` results in an SMTP error (`555 Syntax error`). This is because `curl` wraps the argument in angle brackets, producing `RCPT TO:<Sender Name <user@example.com>>`.

### Root Cause
- **MIME Headers (`To:`, `From:`)**: Displayed to the end-user in mail clients and support display names (e.g., `Name <email>`).
- **SMTP Envelope (`--mail-from`, `--mail-rcpt`)**: Used strictly by SMTP servers to route messages, requiring **raw email addresses** without display names.

### Solution
We separate envelope addresses from display headers by extracting clean email addresses:

```bash
extract_email() {
    local input="$1"
    if [[ "$input" =~ \<([^>]+)\> ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "$input" | xargs
    fi
}
```

---

## 3. Multiple Recipients Support

### Issue
MIME headers format multiple recipients as a comma-separated list (`To: user1@example.com, user2@example.com`), whereas `curl` requires individual `--mail-rcpt` flags for each recipient.

### Solution
We parse comma-separated `MAIL_TO` values, extracting clean email addresses into an array of `--mail-rcpt` arguments while assembling properly formatted (and encoded) MIME `To:` header strings:

```bash
MAIL_RCPT_ARGS=()
TO_HEADER_PARTS=()
IFS=',' read -ra ADDR_ARRAY <<< "$MAIL_TO"
for addr in "${ADDR_ARRAY[@]}"; do
    clean_addr=$(extract_email "$addr")
    if [[ -n "$clean_addr" ]]; then
        MAIL_RCPT_ARGS+=("--mail-rcpt" "$clean_addr")
        # Format display name if present ...
    fi
done
```

---

## 4. Flexible Body Input (Raw Strings vs File Paths) & MIME Structure

### Issue
Users may pass email content either as raw text/HTML strings (`body`, `html_body`) or as paths to generated files (`body_file`, `html_body_file`).

### Solution
The script evaluates both input sources (file path takes precedence if both are given) and builds the appropriate MIME structure:
- **Plain Text Only**: `Content-Type: text/plain; charset="utf-8"`
- **HTML Only**: `Content-Type: text/html; charset="utf-8"`
- **Both Text and HTML**: `Content-Type: multipart/alternative` with standard boundary markers (`--mail-boundary-...`) and Base64-encoded parts.
