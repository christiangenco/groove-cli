# groove-cli

Automated Groove helpdesk inbox triage using Claude.

## Usage

```bash
cd ~/tools/groove-cli

# List unread tickets (read-only)
ruby main.rb list
ruby main.rb list --limit 10

# Triage tickets with Claude AI (modifies ticket state)
ruby main.rb triage

# Preview triage decisions without modifying anything
ruby main.rb triage --dry-run

# Help
ruby main.rb --help
```

## Commands

- **list** — Read-only view of unread inbox tickets
- **triage** — Loop through unread tickets, classify each as `spam`, `archive`, or `star` via Claude, and update ticket state. Use `--dry-run` to preview without changes.

## Environment

Requires `.env` with `GROOVE_API_TOKEN`, `ANTHROPIC_API_KEY`. Optional: `GROOVE_MAILBOX_ID`.
