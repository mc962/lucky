require "../../spec_helper"

include ContextHelper

class CustomRoutes::Index < Lucky::Action
  get "/so_custom" do
    text "test"
  end
end

class CustomRoutes::Put < Lucky::Action
  put "/so_custom" do
    text "test"
  end
end

class CustomRoutes::Post < Lucky::Action
  post "/so_custom" do
    text "test"
  end
end

class CustomRoutes::Delete < Lucky::Action
  delete "/so_custom" do
    text "test"
  end
end

class Tests::IndexPage
  include Lucky::HTMLPage

  def render
    text "Rendered from Tests::IndexPage"
  end
end

class Tests::Index < Lucky::Action
  action do
    render
  end
end

class Tests::New < Lucky::Action
  action do
    text "test"
  end
end

class Tests::Edit < Lucky::Action
  action do
    text "test"
  end
end

class Tests::Show < Lucky::Action
  action do
    text "test"
  end
end

class Tests::Delete < Lucky::Action
  action do
    text "test"
  end
end

class Tests::Update < Lucky::Action
  action do
    text "test"
  end
end

class Tests::Create < Lucky::Action
  action do
    text "test"
  end
end

class PlainText::Index < Lucky::Action
  action do
    text "plain"
  end
end

class RequiredParams::Index < Lucky::Action
  param required_page : Int32

  action do
    text "required param: #{required_page}"
  end
end

abstract class BaseActionWithParams < Lucky::Action
  param inherit_me : String
end

class InheritedParams::Index < BaseActionWithParams
  action do
    text "inherited param: #{inherit_me}"
  end
end

class OptionalParams::Index < Lucky::Action
  param page : Int32?
  param with_default : String? = "default"
  param with_int_default : Int32? = 1
  param with_int_never_nil : Int32 = 1337
  # This is to test that the default value of 'false' is not treated as 'nil'
  param bool_with_false_default : Bool? = false

  action do
    text "optional param: #{page} #{with_int_default} #{with_int_never_nil}"
  end
end

class ParamsWithDefaultParamsLast < Lucky::Action
  param has_default : String = "default"
  param has_nil_default : String?
  param no_default : String

  get "/args-with-defaults" do
    text "doesn't matter"
  end
end

describe Lucky::Action do
  it "has a url helper" do
    Lucky::RouteHelper.configure { settings.base_uri = "example.com" }
    Tests::Index.url.should eq "example.com/tests"
  end

  describe "routing" do
    it "creates URL helpers for the resourceful actions" do
      Tests::Index.path.should eq "/tests"
      Tests::Index.route.should eq Lucky::RouteHelper.new(:get, "/tests")
      Tests::New.path.should eq "/tests/new"
      Tests::New.route.should eq Lucky::RouteHelper.new(:get, "/tests/new")
      Tests::Edit.path("test-id").should eq "/tests/test-id/edit"
      Tests::Edit.with("test-id").should eq Lucky::RouteHelper.new(:get, "/tests/test-id/edit")
      Tests::Show.path("test-id").should eq "/tests/test-id"
      Tests::Show.with("test-id").should eq Lucky::RouteHelper.new(:get, "/tests/test-id")
      Tests::Delete.path("test-id").should eq "/tests/test-id"
      Tests::Delete.with("test-id").should eq Lucky::RouteHelper.new(:delete, "/tests/test-id")
      Tests::Update.path("test-id").should eq "/tests/test-id"
      Tests::Update.with("test-id").should eq Lucky::RouteHelper.new(:put, "/tests/test-id")
      Tests::Create.path.should eq "/tests"
      Tests::Create.route.should eq Lucky::RouteHelper.new(:post, "/tests")
    end

    it "escapes path params" do
      Tests::Edit.path("test/id").should eq "/tests/test%2Fid/edit"
      Tests::Edit.with("test/id").should eq Lucky::RouteHelper.new(:get, "/tests/test%2Fid/edit")
    end

    it "adds routes to the router" do
      assert_route_added? Lucky::Route.new :get, "/tests", Tests::Index
      assert_route_added? Lucky::Route.new :get, "/tests/new", Tests::New
      assert_route_added? Lucky::Route.new :get, "/tests/:id/edit", Tests::Edit
      assert_route_added? Lucky::Route.new :get, "/tests/:id", Tests::Show
      assert_route_added? Lucky::Route.new :delete, "/tests/:id", Tests::Delete
      assert_route_added? Lucky::Route.new :put, "/tests/:id", Tests::Update
      assert_route_added? Lucky::Route.new :post, "/tests", Tests::Create
    end

    it "allows setting custom routes" do
      assert_route_not_added? Lucky::Route.new :get, "/custom_routes", CustomRoutes::Index

      assert_route_added? Lucky::Route.new :get, "/so_custom", CustomRoutes::Index
      assert_route_added? Lucky::Route.new :put, "/so_custom", CustomRoutes::Put
      assert_route_added? Lucky::Route.new :post, "/so_custom", CustomRoutes::Post
      assert_route_added? Lucky::Route.new :delete, "/so_custom", CustomRoutes::Delete
    end
  end

  describe "rendering" do
    it "renders plain text" do
      response = PlainText::Index.new(build_context, params).call
      response.body.should eq "plain"
      response.content_type.should eq "text/plain"
    end

    it "infer the correct HTML page to render" do
      response = Tests::Index.new(build_context, params).call
      response.body.should contain "Rendered from Tests::IndexPage"
      response.content_type.should eq "text/html"
    end
  end

  describe "params" do
    it "can get params" do
      action = PlainText::Index.new(build_context(path: "/?q=test"), params)
      action.params.get(:q).should eq "test"
    end

    it "can get manually defined required params" do
      action = RequiredParams::Index.new(build_context(path: "/?required_page=1"), params)
      action.required_page.should eq 1
    end

    it "adds named arguments to the path" do
      RequiredParams::Index.path(required_page: 7).should eq "/required_params?required_page=7"
    end

    it "adds named arguments to the route" do
      RequiredParams::Index.route(required_page: 7).should eq Lucky::RouteHelper.new(:get, "/required_params?required_page=7")
    end

    it "raises for missing required params" do
      action = RequiredParams::Index.new(build_context(path: ""), params)
      expect_raises(Lucky::Exceptions::MissingParam) { action.required_page }
    end

    it "can inherit params" do
      InheritedParams::Index.path(inherit_me: "inherited").should eq "/inherited_params?inherit_me=inherited"
    end
  end

  it "can add anchors to routes (and escapes them)" do
    Tests::Index.path(anchor: "#foo").should eq "/tests#%23foo"
    Tests::Index.route(anchor: "#foo").path.should eq "/tests#%23foo"
    Tests::Index.url(anchor: "#foo").ends_with?("/tests#%23foo").should be_true
  end

  describe "params with defaults" do
    it "are put at the end of the arg list so the program compiles" do
      ParamsWithDefaultParamsLast.with(no_default: "Yay!")
    end
  end

  describe "optional params" do
    it "are not required in the route helper" do
      path = OptionalParams::Index.path
      path.should eq("/optional_params")
    end

    it "is initialized to nil" do
      action = OptionalParams::Index.new(build_context(path: ""), params)
      action.page.should eq nil
    end

    it "is fetched if present" do
      action = OptionalParams::Index.new(build_context(path: "/?page=3"), params)
      action.page.should eq 3
    end

    it "can be used within the action" do
      response = OptionalParams::Index.new(build_context(path: "/?page=3"), params).call
      response.body.to_s.should eq "optional param: 3 1 1337"
    end

    it "can specify a default value" do
      action = OptionalParams::Index.new(build_context(path: ""), params)
      action.with_default.should eq "default"
    end

    it "overrides the default if present" do
      action = OptionalParams::Index.new(build_context(path: "/?with_int_never_nil=42"), params)
      action.with_int_never_nil.should eq 42
    end

    it "is added as optional argument to the path" do
      OptionalParams::Index.path(page: 7).should eq "/optional_params?page=7"
      OptionalParams::Index.path(page: 7, with_default: "/other").should eq "/optional_params?page=7&with_default=%2Fother"
    end

    it "is added as optional argument to the route" do
      OptionalParams::Index.route(page: 7).should eq Lucky::RouteHelper.new(:get, "/optional_params?page=7")
      OptionalParams::Index.route(page: 7, with_default: "/other").should eq Lucky::RouteHelper.new(:get, "/optional_params?page=7&with_default=%2Fother")
    end

    it "raises when the optional param cannot be parsed into the desired type" do
      expect_raises Lucky::Exceptions::InvalidParam do
        OptionalParams::Index.new(build_context(path: "/?page=no_int"), params()).call
      end
    end

    it "raises when we cannot parse the non-optional param into the desired type" do
      expect_raises Lucky::Exceptions::InvalidParam, "Required param \"with_int_never_nil\" with value \"no_int\" couldn't be parsed to a \"Int32\"" do
        OptionalParams::Index.new(build_context(path: "/?with_int_never_nil=no_int"), params()).call
      end
    end
  end
end

private def assert_route_added?(expected_route)
  Lucky::Router.routes.should contain(expected_route)
end

private def assert_route_not_added?(expected_route)
  Lucky::Router.routes.should_not contain(expected_route)
end
