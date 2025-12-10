#frozen_string_literal: true

require "timeout"
require "net/http"
require "uri"
require "cgi"

module Jekyll
  module Board
    DEFAULTS = {
      'char_limit' => 300,
      'default_avatar' => 'media/default_avatar.png',
      'images_dir' => 'assets/board/images',
      'max_images' => 2,
      'download_timeout' => 10
    }.freeze

    class << self
      def config(site)
        @config ||= DEFAULTS.merge(site.config['boardcfg'] || {})
      end

      def char_count(content)
        return 0 if content.nil? || content.empty?

        text = content.dup
        text.gsub!(/!\[[^\]]*\]\([^)]+\)/, '')
        text.gsub!(/\[([^\]]+)\]\([^)]+\)/, '\1')
        text.gsub!(/(\*\*|__)(.*?)\1/, '\2')
        text.gsub!(/(\*|_)(.*?)\1/, '\2')
        text.gsub!(/~~(.*?)~~/, '\1')
        text.gsub!(/`([^`]+)`/, '\1')
        text.gsub!(/```[\s\S]*?```/, '')

        processed = text.gsub(/\n/, ' ')
        processed = processed.gsub(/\s+/, ' ')
        processed = processed.strip
        processed.length
      end

      def markdown_to_html(text)
        return '' if text.nil? || text.empty?

        result = CGI.escapeHTML(text)
        result.gsub!(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
        result.gsub!(/__(.+?)__/, '<strong>\1</strong>')
        result.gsub!(/\*(.+?)\*/, '<em>\1</em>')
        result.gsub!(/_(.+?)_/, '<em>\1</em>')
        result.gsub!(/~~(.+?)~~/, '<del>\1</del>')
        result.gsub!(/`([^`]+)`/, '<code>\1</code>')
        result.gsub!(/\[([^\]]+)\]\(([^)]+)\)/) do
          link_text = Regexp.last_match(1)
          link_url  = CGI.unescapeHTML(Regexp.last_match(2))
          if link_url.match?(/\Ahttps?:\/\/|mailto:/i)
            %(<a href="#{CGI.escapeHTML(link_url)}" target="_blank" rel="noopener noreferrer">#{link_text}</a>)
          else
            link_text
          end
        end
        result.gsub!(/\n/, '<br>')
        result
      end

      def extract_images(content, max_images)
        return [] if content.nil? || content.empty?
        images = []
        content.scan(/!\[([^\]]*)\]\(([^)]+)\)/) do |alt, url|
          break if images.size >= max_images
          images << { alt_text: alt, original_url: url.strip }
        end
        images
      end

      def download_image(url, dest_dir_abs, web_dir, timeout: 10)
        return nil if url.nil? || url.empty? || !url.match?(/\Ahttps?:\/\//i)

        uri = URI.parse(url)
        ext = File.extname(uri.path).downcase
        ext = '.jpg' if ext.empty? || ext.length > 5
        filename = "#{Digest::MD5.hexdigest(url)[0, 12]}#{ext}"
        fs_path = File.join(dest_dir_abs, filename)
        web_path = File.join('/', web_dir, filename)

        return web_path if File.exist?(fs_path)

        Jekyll.logger.info 'Board:', "Downloading image: #{url}"
        Timeout.timeout(timeout) do
          response = fetch_with_redirects(uri)
          if response.is_a?(Net::HTTPSuccess)
            FileUtils.mkdir_p(dest_dir_abs)
            File.binwrite(fs_path, response.body)
            Jekyll.logger.info 'Board:', "Saved to: #{fs_path}"
            return web_path
          else
            Jekyll.logger.warn 'Board:', "Failed to download #{url}: HTTP #{response&.code}"
            return nil
          end
        end
      rescue StandardError => e
        Jekyll.logger.warn 'Board:', "Error with #{url}: #{e.message}"
        nil
      end

      def fetch_with_redirects(uri, limit = 3)
        raise ArgumentError, 'Too many redirects' if limit == 0
        response = Net::HTTP.start(
          uri.hostname, uri.port,
          use_ssl: uri.scheme == 'https',
          open_timeout: 5, read_timeout: 10
        ) do |http|
          req = Net::HTTP::Get.new(uri)
          req['User-Agent'] = 'Jekyll'
          http.request(req)
        end

        case response
        when Net::HTTPSuccess then response
        when Net::HTTPRedirection
          new_uri = URI.join(uri, response['location'])
          fetch_with_redirects(new_uri, limit - 1)
        else
          response
        end
      end

      def strip_images(content)
        return '' if content.nil?
        content.gsub(/!\[[^\]]*\]\([^)]+\)/, '').strip
      end
    end

    class BoardGenerator < Generator
      safe true
      priority :low

      def generate(site)
        config     = Board.config(site)
        board_coll = site.collections['board']
        return unless board_coll

        Jekyll.logger.info 'Board:', "Processing #{board_coll.docs.size} board posts..."

        images_dir_abs = File.join(site.source, config['images_dir'])

        board_coll.docs.each do |post|
          content = post.content || ''

          images = Board.extract_images(content, config['max_images'])
          downloaded = images.filter_map do |img|
            web_path = Board.download_image(
              img[:original_url],
              images_dir_abs,
              config['images_dir'],
              timeout: config['download_timeout']
            )

            { 'url' => web_path, 'alt' => img[:alt_text], 'original_url' => img[:original_url] } if web_path
          end

          text_content_raw = Board.strip_images(content)
          orig_count = Board.char_count(text_content_raw)

          truncated = orig_count > config['char_limit']
          text_content = text_content_raw[0, config['char_limit']] || ''
          display_count = text_content.length

          content_html = Board.markdown_to_html(text_content)

          post.data['char_count'] = display_count
          post.data['content_html'] = content_html
          post.data['images'] = downloaded
          post.data['truncated'] = truncated

          if truncated
            Jekyll.logger.warn 'Board:', "'#{post.data['title']}' exceeded #{config['char_limit']} chars (#{orig_count}); truncated to #{display_count}."
          end

          original_image_count = content.scan(/!\[[^\]]*\]\([^)]+\)/).size
          if original_image_count > config['max_images']
            Jekyll.logger.warn 'Board:', "'#{post.data['title']}' had #{original_image_count} images, only #{config['max_images']} allowed."
          end
        end

        Jekyll.logger.info 'Board:', 'Done processing board posts.'
      end
    end
  end
end
