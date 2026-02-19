require 'net/http'
require 'json'

class Message
  attr_reader :number, :state, :person_name, :subject, :snippet, :read, :date_sent

  def initialize(groove, data)
    @groove = groove
    @number = data[:number]
    @state = data[:state]
    @person_name = data[:person_name]
    @subject = data[:subject]
    @snippet = data[:snippet]
    @read = data[:read]
    @date_sent = data[:date_sent]
  end

  def to_s
    "From: #{@person_name}\nSubject: #{@subject}\n#{@snippet}"
  end

  def to_h
    {
      number: @number,
      state: @state,
      person_name: @person_name,
      subject: @subject,
      snippet: @snippet,
      read: @read,
      date_sent: @date_sent
    }
  end

  def update!(state:)
    @groove.update_ticket_state(@number, state)
    @state = state
  end
end

class Groove
  BASE_URL = 'https://api.groovehq.com/v1'

  def initialize(api_token, mailbox_id)
    @api_token = api_token
    @mailbox_id = mailbox_id
  end

  def fetch_inbox(limit = 1)
    endpoint = "/tickets?mailbox=#{@mailbox_id}&state=unread&per_page=#{limit}"

    response = request(endpoint)
    tickets = response['tickets'] || []

    # Sort by created_at descending (most recent first)
    tickets.sort_by { |t| t['created_at'] }.reverse.map do |ticket|
      Message.new(self, {
        number: ticket['number'],
        state: ticket['state'],
        person_name: ticket['links']&.dig('customer', 'href')&.split('/')&.last || 'Unknown',
        subject: ticket['title'],
        snippet: ticket['summary'] || '',
        read: ticket['state'] != 'unread',
        date_sent: ticket['created_at']
      })
    end
  end

  def fetch_ticket_messages(ticket_number, per_page = 25)
    endpoint = "/tickets/#{ticket_number}/messages?per_page=#{per_page}"
    response = request(endpoint)
    response['messages'] || []
  end

  def fetch_message(message_id)
    endpoint = "/messages/#{message_id}"
    response = request(endpoint)
    response['message']
  end

  def update_ticket_state(ticket_number, state)
    valid_states = ['unread', 'opened', 'pending', 'closed', 'spam']
    unless valid_states.include?(state)
      raise ArgumentError, "Invalid state: #{state}. Must be one of: #{valid_states.join(', ')}"
    end

    endpoint = "/tickets/#{ticket_number}/state"
    put_request(endpoint, { state: state })
  end

  private

  def request(endpoint)
    uri = URI("#{BASE_URL}#{endpoint}")
    existing_params = URI.decode_www_form(uri.query || '')
    existing_params << ['access_token', @api_token]
    uri.query = URI.encode_www_form(existing_params)

    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      raise "API Error (#{response.code}): #{response.body}"
    end

    JSON.parse(response.body)
  end

  def put_request(endpoint, body = {})
    uri = URI("#{BASE_URL}#{endpoint}")
    uri.query = URI.encode_www_form([['access_token', @api_token]])

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Put.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = body.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise "API Error (#{response.code}): #{response.body}"
    end

    true
  end
end