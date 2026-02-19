require_relative 'Groove'
require_relative 'Agent'
require 'dotenv/load'
require 'pp'

api_token = ENV['GROOVE_API_TOKEN']
mailbox_id = ENV['GROOVE_MAILBOX_ID'] || '9592013345'
anthropic_key = ENV['ANTHROPIC_API_KEY']

unless api_token
  puts "Error: GROOVE_API_TOKEN environment variable is required"
  exit 1
end

unless anthropic_key
  puts "error: anthropic_api_key environment variable is required"
  exit 1
end

groove = Groove.new(api_token, mailbox_id)
agent = Agent.new(anthropic_key)

loop do
  messages = groove.fetch_inbox

  break if messages.empty?

  message = messages.first
  puts "\nTriaging:"
  puts message.to_s
  puts "-" * 50

  category = agent.triage(message.to_s) do
    # Callback to fetch full message content
    puts "Fetching full message content..."
    ticket_messages = groove.fetch_ticket_messages(message.number)

    # Get the latest message's full content
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

  # puts "\nProceed? (Ctrl+C to cancel, Enter to continue)"
  # gets

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
    puts "updated to opened"
  end
end

puts "\nNo more messages to triage!"
