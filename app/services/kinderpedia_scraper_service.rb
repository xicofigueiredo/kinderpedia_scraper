require 'httparty'
require 'nokogiri'
require 'uri'
require 'addressable/uri'

class KinderpediaScraperService
  include HTTParty
  base_uri 'https://usergateway-services.kinderpedia.co'

  def initialize
    @email = ENV['KINDERPEDIA_EMAIL']
    @password = ENV['KINDERPEDIA_PASSWORD']
    @token = nil

    unless @email && @password
      raise "Missing environment variables: KINDERPEDIA_EMAIL and KINDERPEDIA_PASSWORD must be set"
    end
  end

  def login
    response = self.class.post('/api/login', {
      body: {
        email: @email,
        password: @password
      }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'User-Agent' => 'Mozilla/5.0'
      }
    })

    puts "Login response code: #{response.code}"
    puts "Login response body: #{response.body}"

    if response.success?
      json = JSON.parse(response.body)
      @token = json["token"] || json["access_token"] # Adjust key as needed
      @api_key = json["apiKey"]
      puts "Login successful, token: #{@token}, apiKey: #{@api_key}"
      true
    else
      puts "Login failed with status: #{response.code}"
      false
    end
  end

  def download_documents(child_url, storage_subdir: 'documents')
    return false unless login && @token

    child_id = child_url[%r{/view-child/(\d+)/}, 1] || "unknown_child"
    storage_dir = Rails.root.join('storage', storage_subdir, child_id)
    FileUtils.mkdir_p(storage_dir)
    puts "Created storage directory: #{storage_dir}"

    # Download both private and public documents
    private_docs = fetch_documents(child_id, 'children')
    public_docs = fetch_documents(child_id, 'children_public')

    all_documents = (private_docs + public_docs).uniq { |doc| doc['name'] }

    if all_documents.empty?
      puts "No documents found in API response."
      return false
    end

    all_documents.each do |doc|
      file_url = doc['url']
      file_name = doc['name']
      next unless file_url && file_name

      puts "Downloading document: #{file_name}"
      encoded_url = Addressable::URI.encode(file_url)
      file_response = HTTParty.get(encoded_url)

      if file_response.success?
        File.open(storage_dir.join(file_name), 'wb') { |f| f.write(file_response.body) }
        puts "Saved: #{file_name}"
      else
        puts "Failed to download: #{file_name}"
      end
    end

    true
  end

  private

  def fetch_documents(child_id, entity_type)
    api_url = "https://app.kinderpedia.co/web-api/data/documents?entity_type=#{entity_type}&entity_id=#{child_id}"
    response = HTTParty.get(api_url, {
      headers: {
        'x-api-key' => 'Web01TeAi3l4em|v1.0',
        'User-Agent' => 'Mozilla/5.0',
        'Accept' => 'application/json',
        'x-requested-with' => 'XMLHttpRequest',
        'Cookie' => "JWToken=#{@token}"
      }
    })

    puts "#{entity_type} documents API response code: #{response.code}"

    return [] unless response.success?
    json = JSON.parse(response.body)
    json.dig('result', 'documents') || []
  end

end
