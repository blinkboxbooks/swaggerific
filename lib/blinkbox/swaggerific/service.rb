require "yaml"
require "json"
require "digest/sha1"

module Blinkbox
  module Swaggerific
    VERSION = "0.0.1"

    class Service
      @@instances = {}
      @@swagger_store = File.join(__dir__, "../../../public/swagger")
      @@tld_level = 2

      def self.new(file)
        if @@instances[name].nil?
          @@instances[name] = self.allocate
          @@instances[name].send(:initialize_from_swagger, file)
        end
        @@instances[name]
      end

      def self.call(env)
        filename = if File.directory?(@@swagger_store)
          # Multi service mode
          idx = (@@tld_level + 1) * -1
          subdomain = env['HTTP_HOST'].split(".")[0..idx].join(".")
          File.join(@@swagger_store, "#{subdomain}.yaml")
        else
          # Single service mode
          @@swagger_store
        end

        begin
          self.new(filename).response(env)
        rescue Errno::ENOENT
          halt(404, {
            "error" => "missing_swagger",
            "message" => "No swagger file uploaded with the specified name could be found"
          }.to_json)
        end
      end

      def response(env)
        matching_paths = matching_paths(env['REQUEST_PATH'], env['REQUEST_METHOD'].downcase)
        requested_status_code = 200
        case matching_paths.size
        when 0
          halt(404)
        when 1
          spec = matching_paths.first[:spec]['responses'][requested_status_code]
          return halt(404) if spec.nil?

          # TODO: Pick a suitable example based on accept header
          example = spec['examples'].values.first
          content_type = spec['examples'].keys.first
          # TODO: figure out why the JSON is being parsed
          example = example.to_json if content_type == "application/json"

          specified_headers = (spec['headers'] || {}).merge("Content-Type" => content_type)
          halt(requested_status_code, example, specified_headers)
        else
          halt(500, {
            "error" => "route_uncertainty",
            "message" => "Your request matched multiple paths",
            "details" => matching_paths
          }.to_json)
        end
      end

      private

      def halt(status, body = "", extra_headers = {})
        [status, headers(extra_headers), [body]]
      end

      def matching_paths(path, method, content_type = "*/*")
        # TODO: Only match routes which have the correct "consumes" value
        matching_paths = @spec['paths'].keys.map { |spec_path|
          spec_path_re = spec_path.gsub(/\{([^}]+)\}/, "(?<\\1>.+?)")
          matches = Regexp.new("^#{spec_path_re}$").match(path)
          next if matches.nil?
          next if @spec['paths'][path][method].nil?
          {
            spec: @spec['paths'][path][method],
            params: Hash[matches.names.zip(matches.captures)]
          }
        }.compact
      end

      def headers(headers = {})
        {
          "X-Swaggerific-Version" => VERSION,
          "X-Swaggerific-Hash" => @hash,
          "Content-Type" => "application/json" # the default content type
        }.merge(headers)
      end

      def initialize_from_swagger(filename)
        data = File.read(filename)
        @spec = YAML.load(data)
        @hash = Digest::SHA1.hexdigest(data)[0..8]
      end
    end
  end
end
