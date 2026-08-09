# Send Mail Action

A GitHub Composite Action to send text and/or HTML emails via SMTP using `curl`.

## Features

- **Zero Third-Party Dependencies & Security**: Built purely with system-native `bash` and `curl`. Eliminates heavy `node_modules` / Python dependency trees, completely avoiding supply chain attack risks (such as malicious dependency injection) while ensuring maximum safety and portability on any runner.
- **Flexible Body Sources**: Supports raw strings (`body`, `html_body`) as well as local file paths (`body_file`, `html_body_file`).
- **Multipart Support**: Supports sending plain text, HTML, or both simultaneously (`multipart/alternative`).
- **Multiple Recipients & Display Names**: Supports single/multiple recipients with display names (e.g. `Alice <a@example.com>, Bob <b@example.com>`).
- **RFC 2047 Encoding**: Automatically encodes non-ASCII subjects and display names in Base64 to prevent `no subject` or header parsing issues on clients like Gmail/Outlook.
- **Custom Curl Options**: Pass extra flags directly to `curl` via `curl_opts` (e.g. `--insecure`, `-v`, `--connect-timeout 10`).

## Inputs

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `smtp_url` | **Yes** | - | SMTP URL (e.g. `smtps://smtp.gmail.com:465` or `smtp://smtp.example.com:587`) |
| `username` | **Yes** | - | SMTP Username |
| `password` | **Yes** | - | SMTP Password |
| `from` | **Yes** | - | Sender address (e.g. `user@example.com` or `Sender Name <user@example.com>`) |
| `to` | **Yes** | - | Recipient address(es), comma-separated (e.g. `user@example.com`, `Name <user@example.com>`, or `a@ex.com, b@ex.com`) |
| `subject` | **Yes** | - | Email subject line |
| `body` | No | `""` | Plain text content |
| `html_body` | No | `""` | HTML content |
| `body_file` | No | `""` | Path to plain text file |
| `html_body_file` | No | `""` | Path to HTML file |
| `curl_opts` | No | `""` | Additional custom command line options to pass directly to `curl` (e.g. `--insecure -v`) |

> **Note**: At least one of `body`, `html_body`, `body_file`, or `html_body_file` must be provided.

## Usage Examples

### 1. Send Simple Plain Text Email (Single Recipient)

```yaml
steps:
  - name: Send notification email
    uses: jiacai/sendmail-action@v1
    with:
      smtp_url: 'smtps://smtp.gmail.com:465'
      username: ${{ secrets.MAIL_USERNAME }}
      password: ${{ secrets.MAIL_PASSWORD }}
      from: 'CI Notification <ci@example.com>'
      to: 'developer@example.com'
      subject: 'Build Completed Successfully'
      body: 'The build job completed with exit code 0.'
```

### 2. Send to Multiple Recipients with Custom Curl Flags (e.g. Insecure TLS)

```yaml
steps:
  - name: Send email with display names & custom curl flags
    uses: jiacai/sendmail-action@v1
    with:
      smtp_url: 'smtp://internal-mail.example.com:587'
      username: ${{ secrets.MAIL_USERNAME }}
      password: ${{ secrets.MAIL_PASSWORD }}
      from: 'Team Lead <lead@example.com>'
      to: 'Alice Smith <alice@example.com>, Bob <bob@example.com>'
      subject: 'Sprint Review Update'
      body: 'Hi team, the sprint review report is ready.'
      curl_opts: '--insecure -v'
```

### 3. Send HTML Email from File

```yaml
steps:
  - name: Checkout repository
    uses: actions/checkout@v4

  - name: Send HTML Report
    uses: jiacai/sendmail-action@v1
    with:
      smtp_url: 'smtp://smtp.example.com:587'
      username: ${{ secrets.MAIL_USERNAME }}
      password: ${{ secrets.MAIL_PASSWORD }}
      from: 'Report Robot <bot@example.com>'
      to: 'team@example.com, leader@example.com'
      subject: 'Weekly Coverage Report'
      html_body_file: './reports/coverage.html'
```

### 4. Send Both Text and HTML (Multipart)

```yaml
steps:
  - name: Send Multipart Email
    uses: jiacai/sendmail-action@v1
    with:
      smtp_url: 'smtps://smtp.gmail.com:465'
      username: ${{ secrets.MAIL_USERNAME }}
      password: ${{ secrets.MAIL_PASSWORD }}
      from: ${{ secrets.MAIL_USERNAME }}
      to: 'recipient@example.com'
      subject: 'Alert: Server Load High'
      body: 'Server load warning. Please check the dashboard.'
      html_body: '<h1>Server Load Warning</h1><p>Please check the <a href="https://dashboard.example.com">dashboard</a>.</p>'
```

## License

MIT
