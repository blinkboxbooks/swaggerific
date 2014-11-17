require 'active_support/core_ext/string/inflections'

module Blinkbox
  module Swaggerific
    module FakeSinatra
      def headers(headers = {})
        {
          "X-Swaggerific-Version" => VERSION,
          "Access-Control-Allow-Origin" => "*",
          "Content-Type" => "application/json" # the default content type
        }.merge(headers)
      end

      def halt(status, body = "", extra_headers = {})
        headers = headers(extra_headers)
        headers['X-Swaggerific-Hash'] = @hash unless @hash.nil?
        throw :halt, [status, headers, [body]]
      end
    end

    module Helpers
      # TODO: Can I improve this accept header processing?
      def parse_accept_header(header)
        header.split(",").map { |s| s.split(";").first }
      end

      def best_mime_type(given_mime_types, accept_list = [])
        accept_list = parse_accept_header(accept_list) if accept_list.is_a?(String)
        (accept_list || ["*/*"]).each do |accepted|
          accepted_re = Regexp.new('^' + Regexp.escape(accepted).gsub('\*', '.+') + '$')
          chosen = given_mime_types.select { |m| accepted_re.match(m) }.first
          return chosen if !chosen.nil?
        end
        nil
      end

      def headers_from_env(env)
        Hash[env.map { |key, value|
          [Regexp.last_match[1].titleize.tr(' ', '-'), value] if (key =~ /^HTTP_(.+)$/)
        }.compact]
      end
    end
  end
end