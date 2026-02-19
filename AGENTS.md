# groove

Automated Groove helpdesk inbox triage using Claude.

```bash
cd ~/tools/groove
ruby main.rb
```

Loops through unread tickets, classifies each as `spam`, `archive`, or `star` via Claude, and updates the ticket state. Exits when inbox is empty.

Requires `.env` with `GROOVE_API_TOKEN`, `ANTHROPIC_API_KEY`. Optional: `GROOVE_MAILBOX_ID`.
