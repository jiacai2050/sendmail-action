# Send Mail Action

A GitHub Composite Action to send text and/or HTML emails via SMTP using `curl`.

## Features

- **No external heavy dependencies**: Built with `bash` and `curl`.
- **Flexible Body Sources**: Supports raw strings (`body`, `html_body`) as well as local file paths (`body_file`, `html_body_file`).
- **Multipart Support**: Supports sending plain text, HTML, or both simultaneously (`multipart/alternative`).
- **Multiple Recipients**: Supports single or comma-separated recipient lists with display name parsing (`Sender <user@example.com>`).

## Inputs

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `smtp_url` | **Yes** | - | SMTP URL (e.g. `smtps://smtp.gmail.com:465` or `smtp://smtp.example.com:587`) |
| `username` | **Yes** | - | SMTP Username |
| `password` | **Yes** | - | SMTP Password |
| `from` | **Yes** | - | Sender address (e.g., `user@example.com` or `Sender Name <user@example.com>`) |
| `to` | **Yes** | - | Recipient address(es), comma-separated |
| `subject` | **Yes** | - | Email subject |
| `body` | No | `""` | Plain text content |
| `html_body` | No | `""` | HTML content |
| `body_file` | No | `""` | Path to plain text file |
| `html_body_file` | No | `""` | Path to HTML file |

> **Note**: At least one of `body`, `html_body`, `body_file`, or `html_body_file` must be provided.

## Usage Examples

### 1. Send Simple Plain Text Email

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

### 2. Send HTML Email from File

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

### 3. Send Both Text and HTML (Multipart)

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
