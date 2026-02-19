# groove

Automated Groove helpdesk inbox triage. Fetches unread tickets, classifies them using Claude (spam / archive / star), and updates their state.

## Setup

```bash
gem install dotenv
```

Create `.env`:

```
GROOVE_API_TOKEN=your-groove-api-token
GROOVE_API_URL=https://api.groovehq.com/v1
GROOVE_MAILBOX_ID=your-mailbox-id        # optional, has a default
ANTHROPIC_API_KEY=sk-ant-...
```

## Usage

```bash
ruby main.rb
```

Processes unread tickets one at a time in a loop:
1. Fetches the next unread ticket
2. Sends subject/snippet to Claude for classification
3. If Claude needs the full message body, fetches it and re-evaluates
4. Updates ticket state: `spam` → spam, `archive` → closed, `star` → opened
5. Repeats until inbox is empty
