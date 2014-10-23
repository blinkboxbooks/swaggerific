context Blinkbox::Swaggerific::Service do
  describe "stub service" do
    it "must return 404 if there are no routes" do
      stub_swagger(swaggerise({}))
      get "/"
      expect(last_response.status).to eq(404)
    end

    describe "with deprecated endpoints" do
      it "must respond with a 405 without X-Swaggerific-Deprecated-Endpoints set" do
        stub_swagger(swaggerise(pathdef_for("/", deprecated: true)))
        get "/"
        expect(last_response.status).to eq(405)
        response_json = JSON.parse(last_response.body)
        expect(response_json["error"]).to eq("deprecated_endpoint")
        expect(last_response.headers["X-Swaggerific-Deprecated-Endpoint"]).to eq("true")
      end

      it "must respond normally with X-Swaggerific-Deprecated-Endpoints set to allow" do
        body = "abc123"
        stub_swagger(swaggerise(pathdef_for("/", deprecated: true, body: body)))
        get "/", {}, { "HTTP_X_SWAGGERIFIC_DEPRECATED_ENDPOINTS" => "allow" }
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq(body)
        expect(last_response.headers["X-Swaggerific-Deprecated-Endpoint"]).to eq("true")
      end
    end

    describe "with static paths" do
      it "must respond with the example if there is one matching route" do
        [200, 201, 303, 400, 401, 403, 500, 503].each do |status|
          example = "example data for #{status}"
          body = { "path" => example }.to_json
          stub_swagger(
            swaggerise(
              pathdef_for("/", status: status, body: body)
            )
          )
          get "/", {}, { "HTTP_X_SWAGGERIFIC_RESPOND_WITH" => status }
          expect(last_response.body).to eq(body)
          expect(last_response.status).to eq(status)
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
        expect { JSON::Validator.validate!(schema, response_json) }.to_not raise_error
      end

      it "must return 501 with no_example if there is no example or schema" do
        stub_swagger(swaggerise(pathdef_for("/", body: nil)))
        get "/", {}, { "HTTP_ACCEPT" => "application/json" }
        expect(last_response.status).to eq(501)
        response_json = JSON.parse(last_response.body)
        expect(response_json["error"]).to eq("no_example")
      end
    end

    describe "with get parameters" do
      it "must respond with the example if there is one query parameter" do
        stub_swagger(
          swaggerise(
            pathdef_for(
              "/",
              body: { "param" => "%{param}" }.to_json,
              params: [
                {
                  "name" => "param",
                  "in" => "query",
                  "type" => "string"
                }
              ]
            )
          )
        )
        query_params = { "param" => "value" }
        get "/", query_params
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to eq(query_params)
      end

      it "must respond with the example if there are multiple query parameters in another order" do
        stub_swagger(
          swaggerise(
            pathdef_for(
              "/",
              body: { "a" => "%{a}", "b" => "%{b}", "c" => "%{c}" }.to_json,
              params: [
                {
                  "name" => "a",
                  "in" => "query",
                  "type" => "string"
                },
                {
                  "name" => "b",
                  "in" => "query",
                  "type" => "string"
                },
                {
                  "name" => "c",
                  "in" => "query",
                  "type" => "string"
                }
              ]
            )
          )
        )
        query_params = { "a" => "1", "c" => "3", "b" => "2" }
        get "/", query_params
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to eq(query_params)
      end

      it "must respond with the example using defaults if optional query params are missing" do
        default = "Hello there"
        stub_swagger(
          swaggerise(
            pathdef_for(
              "/",
              body: { "param" => "%{param}" }.to_json,
              params: [
                {
                  "name" => "param",
                  "in" => "query",
                  "type" => "string",
                  "default" => default
                }
              ]
            )
          )
        )
        get "/", {}
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to eq("param" => default)
      end

      it "must not make unspecified params available" do
        stub_swagger(
          swaggerise(
            pathdef_for(
              "/",
              body: { "param" => "%{param}" }.to_json,
              params: []
            )
          )
        )
        query_params = { "param" => "value" }
        get "/", query_params
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to_not eq(query_params)
      end
    end
  end
end
