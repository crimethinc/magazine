# IMPORTANT!
# One time use data import / migration tasks
# Delete its support files after its run in production

class MigrateSinglePageToolsFromS3ToActiveStorage
  # Download all of the files from S3, at their conventional URLs
  # Re-upload them using Active Storage

  class << self
    def run
      Sticker.find_each { |sticker| migrate_assets(sticker) }
      Poster.find_each  { |poster|  migrate_assets(poster) }
    end

    # rubocop:disable Metrics/MethodLength
    def migrate_assets tool
      %i[image download].each do |kind|
        %i[front back].each do |side|
          %i[color black_and_white].each do |color|
            next unless tool.send("#{side}_#{color}_#{kind}_present?")

            puts "==>       Working on: #{tool.slug} - #{side} / #{color} / #{kind}"
            # asset URL
            url = if kind == :image
                    tool.image side: side, color: color
                  else
                    tool.download_url side: side, color: color
                  end

            # attach asset to new attribute
            attr_name = kind == :image ? "image_#{side}_#{color}_image" : "image_#{side}_#{color}_download"

            # don't reupload tools that're already uploaded
            if !Rails.env.development? && tool.send(attr_name).attached?
              puts "==>         Skipping: #{tool.slug} - #{side} / #{color} / #{kind}"
              puts
              next
            end

            # file name
            file_name = url.split('/').last

            # fetch asset, save to tmp
            puts "==> Downloading from: #{url}"
            puts "==>        Saving to: tmp/#{file_name}"
            open("tmp/#{file_name}", 'wb') do |file|
              file << URI.parse(url).open.read
            end

            puts "==>   Attaching file: #{file_name}"
            puts "==>               to: #{attr_name}"

            tool.send(attr_name).attach io: File.open("tmp/#{file_name}"), filename: file_name

            # delete tmp file
            puts "==>    Deleting file: tmp/#{file_name}"
            File.delete("tmp/#{file_name}") if File.exist? "tmp/#{file_name}"
            puts

            # try to not fail in production
            sleep 5 unless Rails.env.development?
          end
        end
      end
    end
    # rubocop:enable Metrics/MethodLength
  end
end

namespace :data do
  namespace :uploads do
    desc 'Import translated articles'
    task migrate: :environment do
      MigrateSinglePageToolsFromS3ToActiveStorage.run
    end
  end
end