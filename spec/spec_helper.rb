$LOAD_PATH.unshift File.join(__dir__, "../lib")
require "tempfile"
require "rack/test"
require "json-schema"
require "blinkbox/swaggerific/service"
require "active_support/core_ext/hash/deep_merge"

module Helpers
  def stub_swagger(yaml)
    yaml_file = Tempfile.new(['swagger-', '.yaml'])
    (@temp_files ||= []).push(yaml_file)
    yaml_file.write(yaml)
    yaml_file.close
    Blinkbox::Swaggerific::Service.swagger_store = yaml_file.path
  end

  def pathdef_for(path, method: "get", status: 200, content_type: "application/json", body: { "path" => path }.to_json, schema: nil)
    route = {}
    route.deep_merge!("examples" => { content_type => body }) unless body.nil?
    route.deep_merge!("schema" => schema) unless schema.nil?
    { path => { method => { "responses" => { status => route } } } }
  end

  def swaggerise(*pathdefs)
    YAML.dump("paths" => pathdefs.inject({}) { |paths, pathdef| paths.deep_merge(pathdef) })
  end

  def app
    Blinkbox::Swaggerific::Service
  end
end

RSpec.configure do |c|
  c.include Helpers
  c.include Rack::Test::Methods

  c.before(:each) do
    @logger = instance_double(Logger)
    allow(@logger).to receive(:debug)
    Blinkbox::Swaggerific::Service.logger = @logger
  end

  c.after(:each) do
    (@temp_files ||= []).each do |file|
      file.unlink
    end
  end
end