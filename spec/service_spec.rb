context Blinkbox::Swaggerific::Service do
  describe "stub service" do
    it "must return 404 if there are no routes" do
      stub_swagger(swaggerise({}))
      get "/"
      expect(last_response.status).to eq(404)
    end

    it "must respond with the example if there is one matching route" do
      [200, 201, 303, 400, 401, 403, 500, 503].each do |status|
        example = "example data for #{status}"
        stub_swagger(
          swaggerise(
            pathdef_for("/", status: status, body: { "path" => example }.to_json)
          )
        )
        get "/", {}, { "HTTP_X_SWAGGERIFIC_RESPOND_WITH" => status }
        response_json = nil
        expect { response_json = JSON.parse(last_response.body) }.to_not raise_error
        expect(last_response.status).to eq(status)
        expect(response_json).to eq(response_json)
      end
    end

    it "must return 500 with route_uncertaincy if there is more than one route" do
      stub_swagger(
        swaggerise(
          pathdef_for("/test-path"),
          pathdef_for("/test-{var}")
        )
      )
      get "/test-path"
      expect(last_response.status).to eq(500)
      response_json = JSON.parse(last_response.body)
      expect(response_json["error"]).to eq("route_uncertainty")
    end

    it "must give the example fitting the given accept header" do
      types = ["text/plain", "text/html", "application/something-else"]
      stub_swagger(
        swaggerise(*types.map { |type|
          pathdef_for("/", content_type: type, body: type)
        })
      )
      types.each do |content_type|
        get "/", {}, { "HTTP_ACCEPT" => "#{content_type},*/*" }
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq(content_type)
      end
    end

    it "must return an example that fits the schema if there is a schema but no example" do
      schema = { "type" => "object", "properties" => { "key" => { "type" => "string" } } }
      stub_swagger(swaggerise(pathdef_for("/", body: nil, schema: schema)))
      get "/", {}, { "HTTP_ACCEPT" => "application/json" }
      expect(last_response.status).to eq(200)
      response_json = JSON.parse(last_response.body)
      expect { JSON::Validator.validate(schema, response_json) }.to_not raise_error
    end

    it "must return 501 with no_example if there is no example or schema" do
      stub_swagger(swaggerise(pathdef_for("/", body: nil)))
      get "/", {}, { "HTTP_ACCEPT" => "application/json" }
      expect(last_response.status).to eq(501)
      response_json = JSON.parse(last_response.body)
      expect(response_json["error"]).to eq("no_example")
    end
  end
end
