require "fileutils"

module Blinkbox
  module Swaggerific
    class UploaderService
      CONVERTERS = [
        {
          from_types: ["application/x-yaml", "text/yaml"],
          to_type: "application/json",
          convert_body: proc { |body| YAML.load(body).to_json }
        }
      ].freeze

      class << self
        include Helpers

        def call(env)
          catch :halt do
            path = env['REQUEST_PATH'] || env['REQUEST_URI']
            case env['REQUEST_METHOD'].downcase
            when "get"
              send_file(
                "#{path}.yaml",
                accept: env['HTTP_ACCEPT'],
                headers: { "Access-Control-Allow-Origin" => "*" }
              ) if path =~ %r{^/swag/}
              send_file(
                Regexp.last_match[1],
                root: "editor"
              ) if path =~ %r{^/editor(/.*)$}
              send_file(path, accept: env['HTTP_ACCEPT'])
            when "put"
              halt(404) unless path == "/swag"
              spec = Service.new("meta").spec["paths"]["/swag"]["put"]
              params = Parameters.new(spec["parameters"], env: env).all
              halt(400, {
                "error" => "disallowed_subdomain",
                "message" => "You cannot override the meta subdomain"
              }.to_json) if params[:subdomain] == "meta"
              
              # Using the service's own swagger documentation to populate its responses?! It'll never work!!1!
              halt(415, spec['responses'][415]['examples']['application/json']) unless (Service.valid_swagger?(params[:spec][:tempfile].path))

              begin
                FileUtils.mv(params[:spec][:tempfile].path, File.join(Service.swagger_store, "#{params[:subdomain]}.yaml"))
              rescue e
                halt(500, {
                  "error" => "storage_failure",
                  "message" => "Swaggerific was unable to store the uploaded file",
                  "details" => {
                    "class" => e.class,
                    "message" => e.message
                  }
                }.to_json)
              end

              halt(200, {
                "stubUrl" => "#{env['rack.url_scheme']}://#{params[:subdomain]}.#{env['HTTP_HOST']}",
                "hash" => Service.new(params[:subdomain]).hash
              }.to_json)
            else
              halt(501)
            end
          end
        end

        def send_file(filename, root: "public", accept: "*/*", status: 200, headers: {})
          filename = "/index.html" if filename == "/"
          ext = File.extname(filename)
          filename = File.join(__dir__, "../../../", root, File.expand_path(filename, "/"))
          body = File.read(filename)
          type, body = convert(Rack::Mime.mime_type(ext), accept, body)
          raise unless headers["Content-Type"] = best_mime_type(equivalent_types(type), accept)
          halt(status, body, headers)
        rescue Errno::ENOENT
          # Only return the 404 html if we think that's what they want
          accept = Rack::Mime.mime_type(ext, "text/html") if accept == "*/*"
          send_file("404.html", status: 404) if best_mime_type(["text/html"], accept)
          halt(404)
        end

        def equivalent_types(*type)
          type.push("application/x-yaml") if type.include?("text/yaml")
          type
        end

        def convert(type, accept, body)
          CONVERTERS.each do |c|
            if (c[:from_types].include?(type) && best_mime_type(c[:from_types] + [c[:to_type]], accept) == c[:to_type])
              body = c[:convert_body].call(body)
              type = c[:to_type]
            end
          end
          [type, body]
        end
      end
    end
  end
end