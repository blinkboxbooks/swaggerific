require "tempfile"
require "fileutils"
require "sinatra/base"
require_relative "helpers"

module Blinkbox
  module Swaggerific
    class UploaderService < Sinatra::Base
      include Helpers

      set :root, File.expand_path("../../../", __dir__)

      configure do
        @@spec = Blinkbox::Swaggerific::Service.new("meta").spec
      end

      helpers do
        def upload_swagger!(subdomain, io)
          content_type :json
          halt(400, {
            "error" => "disallowed_subdomain",
            "message" => "You cannot change the meta subdomain"
          }.to_json) if subdomain == "meta"
          halt(415,
            @@spec['paths']['/swag']['put']['responses'][415]['examples']['application/json']
          ) unless Service.valid_swagger?(io.path)

          begin
            FileUtils.mv(io.path, File.join(Service.swagger_store, "#{subdomain}.yaml"))
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
            "stubUrl" => stub_url(subdomain),
            "hash" => Service.new(subdomain).hash
          }.to_json)
        end

        def stub_url(subdomain)
          "#{env['rack.url_scheme']}://#{subdomain}.#{env['HTTP_HOST']}"
        end
      end

      not_found do
        send_file("public/404.html")
      end

      get "/" do
        send_file("public/index.html")
      end

      get %r{^/swag/([a-z0-9\-]+)$} do |subdomain|
        can_provide = %w{text/html application/x-yaml text/yaml application/json}
        filename = File.join(Service.swagger_store, "#{subdomain}.yaml")
        case best_mime_type(can_provide, env['HTTP_ACCEPT'])
        when "text/html"
          uri = URI::HTTP.build(host: env["SERVER_NAME"], port: env['SERVER_PORT'].to_i, path: "/swag/#{subdomain}")
          editor_url = "http://editor.swagger.io/#/edit?import=#{URI.encode(uri.to_s)}"
          erb :'editor.html', locals: {
            editor_url: editor_url,
            stub_url: stub_url(subdomain)
          }
        when "application/x-yaml", "text/yaml"
          headers["Access-Control-Allow-Origin"] = "*"
          send_file(filename)
        when "application/json"
          data = YAML.load(open(filename))
          headers["Access-Control-Allow-Origin"] = "*"
          content_type :json
          halt(200, data.to_json)
        else
          content_type :json
          halt(406, {
            "error" => "not_acceptable",
            "message" => "The requested file formats are not available for this document."
          }.to_json)
        end
      end

      put %r{^/swag/([a-z0-9\-]+)$} do |subdomain|
        io = Tempfile.new
        io.unlink # file reference is deleted; access remains available while handler is open
        request.body.rewind
        io.write request.body
        io.rewind
        upload_swagger!(subdomain, io)
      end

      put "/swag" do
        params = Parameters.new(@@spec['paths']['/swag']['put']['parameters'], env: env).all
        upload_swagger!(params[:subdomain], params[:spec][:tempfile])
      end
    end
  end
end