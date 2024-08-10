# frozen_string_literal: false

require "swagger/blocks"
require "sinatra"
require "sinatra/base"
require "json"
require "erb"
require "require_all"
# DO NOT change the order of loading below.  The files contain executable code that builds the overall configuration before this module starts
require_rel "./routes.rb"
require_rel "../models"
require_rel "../views"
require_rel "../tests"
require_rel "../lib"


class ApplicationController < Sinatra::Application
  include Swagger::Blocks

  set :bind, "0.0.0.0"
  before do
    response.headers["Access-Control-Allow-Origin"] = "*"
  end

  configure do
    set :public_folder, "public"
    set :views, "app/views"
    enable :cross_origin
  end

  options "*" do
    response.headers["Allow"] = "GET, PUT, POST, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type, Accept, X-User-Email, X-Auth-Token"
    response.headers["Access-Control-Allow-Origin"] = "*"
    200
  end

  swagger_root do
    key :swagger, "2.0"
    info do
      key :version, "1.0.0"
      key :title, "FAIR Core Tests"
      key :description, "The core set of FAIR tests used by the FAIR Champion evaluation platform"
      key :termsOfService, "https://example.org"
      contact do
        key :name, "Mark D. Wilkinson"
      end
      license do
        key :name, "MIT"
      end
    end
    # tag do
    #   key :name, $th.keys.first
    #   key :description, 'All Tests'
    #   externalDocs do
    #     key :description, 'Find more info here'
    #     key :url, 'https://fairdata.services/Champion/about'
    #   end
    # end
    key :schemes, ["http"]
    key :host, ENV.fetch("HARVESTER", nil)
    key :basePath, "/tests/"
    #    key :consumes, ['application/json']
    #    key :produces, ['application/json']
  end

  # A list of all classes that have swagger_* declarations.
  SWAGGERED_CLASSES = [ErrorModel, self].freeze

  set_routes(classes: SWAGGERED_CLASSES)

  run! # if app_file == $PROGRAM_NAME
end
