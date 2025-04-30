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

  def download_all
    @scraper = KinderpediaScraperService.new
    @children_ids = @scraper.fetch_all_children

    if @children_ids.empty?
      flash[:alert] = "No children found."
      return redirect_to root_path
    end

    document_type = params[:document_type] || 'documents'
    success_count = 0
    skipped_count = 0
    failed_children = []

    @children_ids.each do |child_data|
      child_id = child_data[:child_id]
      child_url = "https://app.kinderpedia.co/mykp/children/view-child/#{child_id}/general"

      if @scraper.download_documents(child_url, storage_subdir: document_type)
        success_count += 1
      else
        failed_children << child_id
      end
    end

    summary = []
    summary << "Created zip files for #{success_count} children"
    summary << "Failed for #{failed_children.size} children" if failed_children.any?
    summary << "Files are in storage/#{document_type}/"

    flash[:notice] = summary.join("\n")

    if failed_children.any?
      flash[:alert] = "Failed children IDs: #{failed_children.join(', ')}"
    end

    Rails.logger.info "Download completed. Success: #{success_count}, Failed: #{failed_children.size}"
    redirect_to root_path
  end


end
