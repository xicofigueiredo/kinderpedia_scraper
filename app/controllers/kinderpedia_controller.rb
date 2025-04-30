require 'zip'

class KinderpediaController < ApplicationController
  def index
  end

  def download
    @child_url = params[:child_url]
    document_type = params[:document_type] || 'documents'
    @scraper = KinderpediaScraperService.new


      if @scraper.download_documents(@child_url, storage_subdir: document_type)
        child_id = @child_url[%r{/view-child/(\d+)/}, 1] || "unknown_child"
        storage_dir = Rails.root.join('storage', document_type, child_id)
        zip_path = Rails.root.join('storage', document_type, "#{child_id}.zip")

        entries = Dir.entries(storage_dir) - %w[. ..]
        if entries.empty?
          flash[:alert] = "No documents found to zip."
          Rails.logger.error "No documents found in #{storage_dir}"
          return redirect_to root_path
        end

        Zip::File.open(zip_path, Zip::File::CREATE) do |zipfile|
          entries.each do |entry|
            file_path = File.join(storage_dir, entry)
            zipfile.add(entry, file_path) if File.file?(file_path)
          end
        end

        Rails.logger.info "Sending zip file: #{zip_path}"
        send_file zip_path, type: 'application/zip', filename: "#{child_id}.zip"
      else
        flash[:alert] = "Failed to download documents. Please check your credentials and URL."
        Rails.logger.error "KinderpediaScraperService failed to download documents."
        redirect_to root_path
      end

  end

end
