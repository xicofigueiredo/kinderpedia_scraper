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

  def fetch_all_children
    url = "https://app.kinderpedia.co/mykp/children/family/list/active/0?draw=1&start=0&length=1000"

    headers = {
      'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
      'Accept' => 'application/json, text/javascript, */*; q=0.01',
      'x-requested-with' => 'XMLHttpRequest',
      'Referer' => 'https://app.kinderpedia.co/mykp/children/family/list',
      'Cookie' => '_fbp=fb.1.1744636965113.287244512380077365; _gcl_au=1.1.2037038041.1744636965; hubspotutk=bd06359308846bc04a6a3febb2e46b19; __hstc=133375057.bd06359308846bc04a6a3febb2e46b19.1744637019120.1744637019120.1746028338700.2; __hssrc=1; _ga=GA1.1.33057958.1746028339; intercom-id-obupjdit=6b087761-0f93-44d1-9353-c94d7824b7ba; intercom-device-id-obupjdit=77c8f069-1ab2-4294-b0cf-fc604b307c0b; applicationType=teacher; PHPSESSID=4dca315d1b77be6729f75fb91b65edcb; sidebar_closed=1; JWToken=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE3NDYwMjk4ODMsImV4cCI6MTc0NjAzNzA4Mywicm9sZXMiOlsiUk9MRV9VU0VSIl0sImVtYWlsIjoiY29udGFjdEBicmF2ZWdlbmVyYXRpb25hY2FkZW15LmNvbSJ9.E1pexF0izcUDUMMhyx0sBWGtIM5UhLjrlTndKsuztDI; Refresh-Token=dae13fe719c146d52c995543b7f8ff719d37acbe333c5ff9f36a0d84ae65d725a5a1fe2395275dd106526c91147ae4893fcc5269064a3dfc3a1056aeb5bfe6d1; cf_clearance=udcplXYtNvtyxYgbCTBe.s9fCnE9LdRBXOllb.KtsZE-1746035882-1.2.1.1-RR1GvHnfGmfSOrL4sXwd_ZAqY6.bq.Ahc1naY7tcra9eb4p32uYsveTM7H5Z60h46EsaBTH.aK_Hp7j_cY5h61Hk_hfL.seRuaa2i8b2dwaFkTQ9pfsO.3eFzNYY_V7uVeyJ0DCfCfpm5DaKtSQMq0vb.Z.xYRWGozKVDcRdYMkVVDz4AFzlEgZzKHXd8.nayofpL.LfXykeW..6Q_VXDp6YS7hx6L.S0gOToh8lYYOGjIGk.BFAe2jlWFMdZLGYfhJhL6HC7rGwI5mK711AVzxOzfBEdl_0XF9crC0HBBulAXMwqndpI_nk2kp6GWyvir5d9i5HrW96eBUlhmbJAw0k0dEeHUosduVlVwhxTRE; intercom-session-obupjdit=UU91MllCNVY3MWtsQnFxWHNxUHAra2ZtakphRVZldDhHbDM0WE9reHd3YlAvRlQxZ0RQS0o2Rmw2NGVYTTB0QXZGN0c4NzJnYnRPVllPMnlFQTRhQ3VGc1d2Nk1RTktYUzNWajN5U1BmMzA9LS1RL0VtU2lVeEMrWWVxVWF1bkV3MlpBPT0=--561cd8d9befb802ecff92330743db4945043b337; _ga_0RFGRKYM5Y=GS1.1.1746028339.1.1.1746036119.60.0.0; _ga_9CFS1VMQ89=GS1.1.1746028339.1.1.1746036119.60.0.0; _ga_35Q17HW8BG=GS1.1.1746028339.1.1.1746036119.60.0.0; _ga_SQ2QLPWJ8B=GS1.1.1746028339.1.1.1746036119.60.0.0'
    }

    response = HTTParty.get(url, headers: headers)
    puts "Fetch children response code: #{response.code}"

    json = JSON.parse(response.body)
    data_rows = json['data'] || []

    # Extract both child ID and family ID from the HTML content
    children_data = data_rows.flat_map do |row|
      # Extract family ID from the family management link
      family_id = row[1].match(/\/mykp\/children\/family\/manage\/(\d+)/)&.captures&.first

      # Extract all child IDs from the children column (row[2])
      child_ids = row[2].scan(/\/view-child\/(\d+)/).flatten

      # Create an entry for each child in the family
      child_ids.map do |child_id|
        {
          child_id: child_id,
          family_id: family_id
        }
      end
    end.compact # Remove any entries where IDs couldn't be extracted

    puts "Fetched #{children_data.length} children with their family IDs"
    children_data
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

    downloaded_count = 0
    skipped_count = 0

    all_documents.each do |doc|
      file_url = doc['url']
      file_name = doc['name']
      next unless file_url && file_name

      # Sanitize the file name by replacing invalid characters
      sanitized_name = sanitize_filename(file_name)
      file_path = storage_dir.join(sanitized_name)

      if File.exist?(file_path) && File.size(file_path) > 0
        puts "Skipping existing file: #{sanitized_name}"
        skipped_count += 1
        next
      end

      puts "Downloading document: #{file_name} as #{sanitized_name}"
      encoded_url = Addressable::URI.encode(file_url)
      file_response = HTTParty.get(encoded_url)

      if file_response.success?
        File.open(file_path, 'wb') { |f| f.write(file_response.body) }
        puts "Saved: #{sanitized_name}"
        downloaded_count += 1
      else
        puts "Failed to download: #{file_name}"
      end
    end

    puts "Download summary for child #{child_id}:"
    puts "- Downloaded: #{downloaded_count} new files"
    puts "- Skipped: #{skipped_count} existing files"
    puts "- Total files: #{downloaded_count + skipped_count}"

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

  def sanitize_filename(filename)
    # Remove or replace invalid characters
    sanitized = filename.gsub(%r{[/\\?%*:|"<>]}, '_')
    # Replace multiple spaces/underscores with a single underscore
    sanitized = sanitized.gsub(/\s+/, '_')
    # Remove any leading/trailing spaces or dots
    sanitized = sanitized.strip.gsub(/^\.+|\.+$/, '')
    # Ensure the filename is not empty
    sanitized.presence || 'unnamed_file'
  end

end


# 'Cookie' => '_fbp=fb.1.1744636965113.287244512380077365; _gcl_au=1.1.2037038041.1744636965; hubspotutk=bd06359308846bc04a6a3febb2e46b19; __hstc=133375057.bd06359308846bc04a6a3febb2e46b19.1744637019120.1744637019120.1746028338700.2; __hssrc=1; _ga=GA1.1.33057958.1746028339; intercom-id-obupjdit=6b087761-0f93-44d1-9353-c94d7824b7ba; intercom-device-id-obupjdit=77c8f069-1ab2-4294-b0cf-fc604b307c0b; applicationType=teacher; PHPSESSID=4dca315d1b77be6729f75fb91b65edcb; sidebar_closed=1; JWToken=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE3NDYwMjk4ODMsImV4cCI6MTc0NjAzNzA4Mywicm9sZXMiOlsiUk9MRV9VU0VSIl0sImVtYWlsIjoiY29udGFjdEBicmF2ZWdlbmVyYXRpb25hY2FkZW15LmNvbSJ9.E1pexF0izcUDUMMhyx0sBWGtIM5UhLjrlTndKsuztDI; Refresh-Token=dae13fe719c146d52c995543b7f8ff719d37acbe333c5ff9f36a0d84ae65d725a5a1fe2395275dd106526c91147ae4893fcc5269064a3dfc3a1056aeb5bfe6d1; cf_clearance=udcplXYtNvtyxYgbCTBe.s9fCnE9LdRBXOllb.KtsZE-1746035882-1.2.1.1-RR1GvHnfGmfSOrL4sXwd_ZAqY6.bq.Ahc1naY7tcra9eb4p32uYsveTM7H5Z60h46EsaBTH.aK_Hp7j_cY5h61Hk_hfL.seRuaa2i8b2dwaFkTQ9pfsO.3eFzNYY_V7uVeyJ0DCfCfpm5DaKtSQMq0vb.Z.xYRWGozKVDcRdYMkVVDz4AFzlEgZzKHXd8.nayofpL.LfXykeW..6Q_VXDp6YS7hx6L.S0gOToh8lYYOGjIGk.BFAe2jlWFMdZLGYfhJhL6HC7rGwI5mK711AVzxOzfBEdl_0XF9crC0HBBulAXMwqndpI_nk2kp6GWyvir5d9i5HrW96eBUlhmbJAw0k0dEeHUosduVlVwhxTRE; intercom-session-obupjdit=UU91MllCNVY3MWtsQnFxWHNxUHAra2ZtakphRVZldDhHbDM0WE9reHd3YlAvRlQxZ0RQS0o2Rmw2NGVYTTB0QXZGN0c4NzJnYnRPVllPMnlFQTRhQ3VGc1d2Nk1RTktYUzNWajN5U1BmMzA9LS1RL0VtU2lVeEMrWWVxVWF1bkV3MlpBPT0=--561cd8d9befb802ecff92330743db4945043b337; _ga_0RFGRKYM5Y=GS1.1.1746028339.1.1.1746036119.60.0.0; _ga_9CFS1VMQ89=GS1.1.1746028339.1.1.1746036119.60.0.0; _ga_35Q17HW8BG=GS1.1.1746028339.1.1.1746036119.60.0.0; _ga_SQ2QLPWJ8B=GS1.1.1746028339.1.1.1746036119.60.0.0'
