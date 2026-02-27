require 'net/http'
require 'json'

class Agent
  API_URL = 'https://api.anthropic.com/v1/messages'

  def initialize(api_key)
    @api_key = api_key
  end

  def triage(email_content, &get_full_message_callback)
    tools = [
      {
        name: "get_full_message",
        description: "Get the full message content including body text. Use this if you need to see the complete message to make a triage decision.",
        input_schema: {
          type: "object",
          properties: {},
          required: []
        }
      },
      {
        name: "triage_email",
        description: "Categorize this email from the Fileinbox help desk inbox into spam, archive, star, or nil (unsure). Use 'spam' for junk/promotional emails, 'archive' for informational emails that don't need action, 'star' for important emails requiring attention, and nil if you're unsure how to categorize it. Err on the side of caution: an important email incorrectly categorized as spam is much worse than a spam email incorrectly starred. Fetch the full email if you're not sure. Emails in response to a subscription renewing soon are likely important. Also emails that mention downtime for Fileinbox or something broken in the site.",
        input_schema: {
          type: "object",
          properties: {
            category: {
              type: "string",
              enum: ["spam", "archive", "star", "nil"],
              description: "The triage category for this email"
            },
            reasoning: {
              type: "string",
              description: "Brief explanation of why this category was chosen"
            }
          },
          required: ["category"]
        }
      }
    ]

    messages = [{
      role: "user",
      content: "Please triage this email and use the triage_email tool to categorize it:\n\n#{email_content}"
    }]

    loop do
      response = api_request(messages, tools)

      # Add assistant response to messages
      messages << { role: "assistant", content: response['content'] }

      # Extract tool uses from the response
      tool_uses = response['content'].select { |block| block['type'] == 'tool_use' }

      # If no tool uses, something went wrong
      break if tool_uses.empty?

      # Process each tool use
      tool_results = []
      tool_uses.each do |tool_use|
        case tool_use['name']
        when 'get_full_message'
          if get_full_message_callback
            full_content = get_full_message_callback.call
            tool_results << {
              type: "tool_result",
              tool_use_id: tool_use['id'],
              content: full_content
            }
          else
            tool_results << {
              type: "tool_result",
              tool_use_id: tool_use['id'],
              content: "Full message content not available"
            }
          end
        when 'triage_email'
          # This is the final action, return the category
          if tool_use['input']['category']
            category = tool_use['input']['category']
            return category == 'nil' ? nil : category
          end
        end
      end

      # Add tool results to messages and continue the loop
      messages << { role: "user", content: tool_results } unless tool_results.empty?
    end

    nil # Default if something goes wrong
  end

  private

  def api_request(messages, tools)
    uri = URI(API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['x-api-key'] = @api_key
    request['anthropic-version'] = '2023-06-01'

    body = {
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1024,
      tools: tools,
      messages: messages
    }
    request.body = body.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise "Anthropic API Error (#{response.code}): #{response.body}"
    end

    JSON.parse(response.body)
  end
end
