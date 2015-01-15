require "yaml"
require "json"
require "faker"
require "genny"
require "logger"
require "digest/sha1"
require_relative "helpers"
require_relative "examplers"

module Blinkbox
  module Swaggerific
    class Service
      include FakeSinatra
      include Helpers
      attr_reader :spec, :hash
      
      @@instances = {}
      @@swagger_store = File.join(__dir__, "../../../public/swag")
      @@tld_level = 2
      @@logger = Logger.new(STDOUT)

      class << self
        def call(env)
          if File.directory?(@@swagger_store)
            # Multi service mode
            idx = (@@tld_level + 1) * -1
            filename_or_subdomain = env['HTTP_HOST'].split(".")[0..idx].join(".")
            return UploaderService.call(env) if ["", "www"].include? filename_or_subdomain
          else
            # Single service mode
            filename_or_subdomain = @@swagger_store
          end

          self.new(filename_or_subdomain).response(env)
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
      end

      def initialize(filename_or_subdomain)
        filename = File.expand_path(filename_or_subdomain.include?("/") ? filename_or_subdomain : File.join(@@swagger_store, "#{filename_or_subdomain}.yaml"))
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

      def response(env)
        return @canned_response if @canned_response
        catch :halt do
          matching_paths = matching_paths(env)
          case matching_paths.size
          when 0
            halt(404)
          when 1
            locale = I18n.exists?(:faker, env['HTTP_ACCEPT_LANGUAGE']) ? env['HTTP_ACCEPT_LANGUAGE'] : "en-GB"
            I18n.with_locale(locale) do
              process_path(env, matching_paths.first)
            end
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
      rescue => e
        logger.fatal(e)
        [500, {}, []]
      end

      private

      def process_path(env, operation: {}, path_params: {}, query_params: {})
        status_code = determine_best_status_code(env, operation['responses'].keys)
        route = operation['responses'][status_code]
        no_route! if route.nil?
        specified_headers = route['headers'] || {}
        check_deprecated!(env, operation, specified_headers)
        check_content_type!(env, operation)
        
        params = Parameters.new(
          operation['parameters'] || {},
          path: path_params,
          env: env,
          query: query_params
        )

        content_type, example = create_example(env, route)
        # Attempt to substitue params into the example, but fallback on the original
        example = example % params.all rescue example

        specified_headers.merge!("Content-Type" => content_type)
        halt(status_code, example, specified_headers)
      end

      def create_example(env, route)
        (route['schema']['definitions'] ||= {}).merge!(@spec['definitions']) if @spec['definitions']
        sources = [
          ExamplesExampler.from_examples(route['examples']),
          SchemaExampler.from_schema(route['schema'])
        ].compact

        sources.reverse! if env['HTTP_X_SWAGGERIFIC_RESPOND_FROM'] == "schema"

        generatable_types = sources.map { |ex| ex.generatable_types }.flatten.uniq
        content_type = best_mime_type(generatable_types, env['HTTP_ACCEPT'])

        example = nil
        sources.each do |s|
          example ||= s.example(content_type)
          break if !example.nil?
        end
        
        halt(501, {
          "error" => "no_example",
          "message" => "The Swagger docs don't specify a suitable example for this route",
          "details" => {
            "routeDescription" => route['description'] || ""
          }
        }.to_json) if example.nil?

        [content_type, example]
      end

      def example_from_examples()

      end

      def example_from_schema()

      end

      def check_deprecated!(env, operation, specified_headers)
        if operation["deprecated"]
          specified_headers["X-Swaggerific-Deprecated-Endpoint"] = "true"
          halt(405,
            {
              "error" => "deprecated_endpoint",
              "message" => "This endpoint has been flagged as deprecated. Please set the X-Swaggerific-Deprecated-Endpoints header to `allow` if you still want to use it, but avoid doing so if possible."
            }.to_json,
            specified_headers
          ) unless env["HTTP_X_SWAGGERIFIC_DEPRECATED_ENDPOINTS"] == "allow"
        end
      end

      def check_content_type!(env, operation)
        return if operation['consumes'].nil?
        acceptable_type = best_mime_type([env['CONTENT_TYPE'].split(';').first], operation['consumes'])
        if acceptable_type.nil?
          halt(415, {
            "error" => "unnacceptable_content_type",
            "message" => "The Content-Type given in the request cannot be dealt with by this endpoint",
            "details" => {
              "delivered" => env['CONTENT_TYPE'].split(';').first,
              "required" => operation['consumes']
            }
          }.to_json)
        end
      end

      def no_route!
        halt(404, {
          "error" => "no_route",
          "message" => "This route is not defined in the Swagger doc"
        }.to_json)
      end

      def determine_best_status_code(env, availble_status_codes)
        requested = env['HTTP_X_SWAGGERIFIC_RESPOND_WITH']
        halt(400, {
          "error" => "invalid_status_code_request",
          "message" => "The X-Swaggerific-Respond-With header must be an http status code"
        }.to_json) unless requested.nil? || requested =~ /^([1-5]\d\d)?$/
        matcher = requested || /^2\d\d$/
        chosen = availble_status_codes.select { |code| code.to_s.match(matcher) }.first
        halt(501, {
          "error" => "no_route",
          "message" => "The Swagger docs don't specify a response with a #{requested || "2xx"} status code"
        }.to_json) if chosen.nil?
        chosen
      end

      def matching_paths(env)
        path = env['PATH_INFO']
        method = env['REQUEST_METHOD'].downcase
        given_query_params = Rack::Utils.parse_nested_query(env['QUERY_STRING'] || "")
        # TODO: Only match routes which have the correct "consumes" value
        matching_paths = (@spec['paths'] || {}).keys.map { |spec_full_path|
          spec_path, spec_query_string = spec_full_path.split("?", 2)
          from_path = match_string(spec_path, path)
          next if from_path.nil?
          operation = @spec['paths'][spec_full_path][method]
          next if operation.nil?
          from_query = (operation["parameters"] || []).inject({}) do |accumulator, param|
            if param["in"] == "query"
              value = given_query_params[param["name"]] || param["default"]
              accumulator.merge!(param["name"] => value) unless value.nil?
            end
            accumulator
          end
          required_get_params = (operation["parameters"] || []).map { |param|
            param["name"] if param["in"] == "query" && param["required"] == true
          }.compact
          next unless (required_get_params - from_query.keys).empty?
          {
            operation: operation,
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

      def logger
        @@logger
      end
    end
  end
end
