require "yaml"
require "json"
require "logger"
require "digest/sha1"
require "blinkbox/swaggerific/version"
require "blinkbox/swaggerific/helpers"
require "blinkbox/swaggerific/parameters"
require "blinkbox/swaggerific/schema_exampler"
require "blinkbox/swaggerific/uploader_service"

module Blinkbox
  module Swaggerific
    class Service
      include Helpers
      attr_reader :spec, :hash
      
      @@instances = {}
      @@swagger_store = File.join(__dir__, "../../../public/swag")
      @@tld_level = 2
      @@logger = Logger.new(STDOUT)

      class << self
        def new(filename_or_subdomain)
          file = filename_or_subdomain.include?("/") ? filename_or_subdomain : File.join(@@swagger_store, "#{filename_or_subdomain}.yaml")
          if @@instances[file].nil?
            @@instances[file] = self.allocate
            @@instances[file].send(:initialize_from_swagger, File.expand_path(file))
          end
          @@instances[file]
        rescue
          @@instances.delete(file)
          raise "No such file or subdomain"
        end

        def tld_level=(number)
          raise ArgumentError, "tld_level must be a positive integer" unless number.to_i > 0
          @@tld_level = number
        end

        def swagger_store
          @@swagger_store
        end

        def swagger_store=(store)
          if File.directory?(store)
            @@swagger_store = store
            return
          end

          raise ArgumentError, "swagger_store must be a folder or a swagger file" unless File.exist?(store)
          raise ArgumentError, "The specified file is not a swagger 2.0 file" if valid_swagger?(ENV['SWAGGERIFIC_SINGLE_SERVICE'])
          @@swagger_store = store
        end

        def valid_swagger?(filename)
          spec = YAML.load(open(filename))
          !(spec.nil? || spec['swagger'].to_f < 2.0)
        rescue
          false
        end

        def logger=(logger)
          @@logger = logger
        end

        def call(env)
          if File.directory?(@@swagger_store)
            # Multi service mode
            idx = (@@tld_level + 1) * -1
            filename_or_subdomain = env['HTTP_HOST'].split(".")[0..idx].join(".")

            return UploaderService.call(env) if filename_or_subdomain == ""
          else
            # Single service mode
            filename_or_subdomain = @@swagger_store
          end

          self.new(filename_or_subdomain).response(env)
        end
      end

      def response(env)
        return @canned_response if @canned_response
        catch :halt do
          matching_paths = matching_paths(env)
          case matching_paths.size
          when 0
            halt(404)
          when 1
            process_path(env, matching_paths.first)
          else
            halt(500, {
              "error" => "route_uncertainty",
              "message" => "Your request matched multiple paths",
              "details" => {
                "matchingPaths" => matching_paths
              }
            }.to_json)
          end
        end
      end

      private

      def process_path(env, spec: {}, path_params: {}, query_params: {})
        requested_status_code = determine_requested_status_code(env)
        route = spec['responses'][requested_status_code]
        halt(404, {
          "error" => "no_route",
          "message" => "This route is not defined in the Swagger doc"
        }.to_json) if route.nil?
        halt(415, {
          "error" => "unnacceptable_content_type",
          "message" => "The Content-Type given in the request cannot be dealt with by this endpoint"
        }.to_json) unless spec['consumes'].nil? || best_mime_type([env['CONTENT_TYPE'].split(';').first], spec['consumes'])

        params = Parameters.new(
          spec['parameters'] || {},
          path: path_params,
          env: env,
          query: query_params,
          header: Hash[env.map { |key, value|
            if (key =~ /^HTTP_(.+)$/)
              [Regexp.last_match[1].downcase.tr("_", "-"), value]
            end
          }.compact]
        )

        example_content_types = route['examples'].keys rescue []
        generatable_examples = route['schema'] ? ["application/json"] : []
        content_type = best_mime_type(example_content_types + generatable_examples, env['HTTP_ACCEPT'])

        if example_content_types.include?(content_type)
          example = route['examples'][content_type]
        elsif !generatable_examples.empty?
          schema_exampler = SchemaExampler.new(route['schema'], @spec['definitions'] || {}, additional_properties: 1)
          example = schema_exampler.gen.to_json
        else
          halt(501, {
            "error" => "no_example",
            "message" => "The Swagger docs don't specify a suitable example for this route",
            "details" => {
              "routeDescription" => route['description'] || ""
            }
          }.to_json)
        end
        
        if !example.is_a?(String)
          logger.warn "The example given is not a string, the Swagger documentation is probably incorrect."
          example = example.to_s
        end

        # Attempt to substitue params into the example, but fallback on the original
        example = example % params.all rescue example

        specified_headers = (route['headers'] || {}).merge("Content-Type" => content_type)
        halt(requested_status_code, example, specified_headers)
      end

      def determine_requested_status_code(env)
        requested_status_code = (env['HTTP_X_SWAGGERIFIC_RESPOND_WITH'] || 200).to_i
        halt(400, {
          "error" => "invalid_status_code_request",
          "message" => "The X-Swaggerific-Respond-With header must be an http status code"
        }.to_json) if requested_status_code == 0
        requested_status_code
      end

      def matching_paths(env)
        path = env['PATH_INFO']
        method = env['REQUEST_METHOD'].downcase
        get_params = required_get_params = Rack::Utils.parse_nested_query(env['QUERY_STRING'] || "")
        # TODO: Only match routes which have the correct "consumes" value
        matching_paths = @spec['paths'].keys.map { |spec_full_path|
          spec_path, spec_query_string = spec_full_path.split("?", 2)
          from_path = match_string(spec_path, path)
          next if from_path.nil?
          next if @spec['paths'][spec_full_path][method].nil?
          required_get_params = Rack::Utils.parse_nested_query(spec_query_string || "")
          next unless (required_get_params.keys - get_params.keys).empty?
          from_query = required_get_params.inject({}) do |params, required|
            params.merge!(match_string(required.last, get_params[required.first]))
          end
          {
            spec: @spec['paths'][spec_full_path][method],
            path_params: from_path,
            query_params: from_query
          }
        }.compact
      end

      def match_string(bracketed_string, match_string, uri_decode: true)
        re = bracketed_string.gsub(/\{([^}]+)\}/, "(?<\\1>.+?)")
        matches = Regexp.new("^#{re}$").match(match_string)
        return nil if matches.nil?
        captures = matches.captures
        captures.map! { |capture| URI.unescape(capture) } if uri_decode
        Hash[matches.names.zip(captures)]
      end

      def initialize_from_swagger(filename)
        logger.debug "Creating Swaggerific instance from #{filename}"
        data = File.read(filename)
        @spec = YAML.load(data)
        @hash = Digest::SHA1.hexdigest(data)[0..8]
      rescue => e
        logger.debug "No docs for #{filename}: #{e.class}"
        body = {
          "error" => "missing_swagger",
          "message" => "No swagger file uploaded with the specified name could be found",
          "details" => {
            "filename" => File.basename(filename)
          }
        }.to_json
        @canned_response = [404, headers, [body]]
      end

      def logger
        @@logger
      end
    end
  end
end
