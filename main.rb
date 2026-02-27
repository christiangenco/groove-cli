require_relative 'Groove'
require_relative 'Agent'
require 'dotenv/load'
require 'optparse'
require 'pp'

HELP = <<~HELP
  Usage: ruby main.rb <command> [options]

  Commands:
    list              List unread inbox tickets (read-only)
    triage            Triage inbox tickets using Claude AI

  Options:
    --dry-run         Show triage decisions without updating ticket state
    --limit N         Number of tickets to process (default: all for triage, 25 for list)
    -h, --help        Show this help message

  Examples:
    ruby main.rb list
    ruby main.rb triage --dry-run
    ruby main.rb triage
    ruby main.rb list --limit 10
HELP

# Parse options
options = { dry_run: false, limit: nil }
remaining_args = []

args = ARGV.dup
while arg = args.shift
  case arg
  when '--dry-run'
    options[:dry_run] = true
  when '--limit'
    options[:limit] = args.shift&.to_i
  when '-h', '--help'
    puts HELP
    exit 0
  else
    remaining_args << arg
  end
end

command = remaining_args.first

if command.nil?
  puts HELP
  exit 1
end

unless ['list', 'triage'].include?(command)
  puts "Unknown command: #{command}"
  puts HELP
  exit 1
end

api_token = ENV['GROOVE_API_TOKEN']
mailbox_id = ENV['GROOVE_MAILBOX_ID'] || '9592013345'
anthropic_key = ENV['ANTHROPIC_API_KEY']

unless api_token
  puts "Error: GROOVE_API_TOKEN environment variable is required"
  exit 1
end

if command == 'triage' && !anthropic_key
  puts "Error: ANTHROPIC_API_KEY environment variable is required for triage"
  exit 1
end

groove = Groove.new(api_token, mailbox_id)

case command
when 'list'
  limit = options[:limit] || 25
  messages = groove.fetch_inbox(limit)
  if messages.empty?
    puts "No unread messages."
  else
    messages.each_with_index do |msg, i|
      puts "##{msg.number} [#{msg.state}] #{msg.date_sent}"
      puts "  From: #{msg.person_name}"
      puts "  Subject: #{msg.subject}"
      puts "  #{msg.snippet}" unless msg.snippet.to_s.empty?
      puts
    end
    puts "#{messages.length} unread ticket(s)"
  end

when 'triage'
  agent = Agent.new(anthropic_key)
  dry_run_label = options[:dry_run] ? " (DRY RUN)" : ""

  loop do
    messages = groove.fetch_inbox(options[:limit] || 1)
    break if messages.empty?

    message = messages.first
    puts "\nTriaging#{dry_run_label}:"
    puts message.to_s
    puts "-" * 50

    category = agent.triage(message.to_s) do
      puts "Fetching full message content..."
      ticket_messages = groove.fetch_ticket_messages(message.number)

      if ticket_messages.any?
        latest_message_id = ticket_messages.first['href'].split('/').last
        full_message = groove.fetch_message(latest_message_id)
        "Full message body:\n#{full_message['plain_text_body'] || full_message['body']}"
      else
        "No messages found for this ticket"
      end
    end

    puts "Category: "
    pp category

    if options[:dry_run]
      puts "⏭  Dry run — skipping state update for ##{message.number}"
      # In dry run with no limit, we'd loop forever on the same ticket
      break
    else
      case category
      when 'spam'
        message.update!(state: 'spam')
        puts "✓ Updated ticket to spam"
      when 'archive'
        message.update!(state: 'closed')
        puts "✓ Updated ticket to closed"
      when 'star'
        message.update!(state: 'opened')
        puts "✓ Updated ticket to opened"
      when nil
        message.update!(state: 'opened')
        puts "✓ Updated to opened"
      end
    end
  end

  puts "\nNo more messages to triage!"
end
