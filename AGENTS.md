# groove-cli

Automated Groove helpdesk inbox triage using Claude.

## Usage

```bash
# List unread tickets (read-only)
groove-cli list
groove-cli list --limit 10

# Triage tickets with Claude AI (modifies ticket state)
groove-cli triage

# Preview triage decisions without modifying anything
groove-cli triage --dry-run

# Help
groove-cli --help
```

## Commands

- **list** — Read-only view of unread inbox tickets
- **triage** — Loop through unread tickets, classify each as `spam`, `archive`, or `star` via Claude, and update ticket state. Use `--dry-run` to preview without changes.

## Environment

Requires `.env` with `GROOVE_API_TOKEN`, `ANTHROPIC_API_KEY`. Optional: `GROOVE_MAILBOX_ID`.
