# frozen_string_literal: false

def set_routes(classes: allclasses)
  set :server_settings, timeout: 180
  set :public_folder, 'public'
  set :port, 8282

  get '/' do
    content_type :json
    response.body = JSON.dump(Swagger::Blocks.build_root_json(classes))
  end

  get '/tests' do
    ts = Dir[File.dirname(__FILE__) + "/../tests/*.rb"]
    @tests = ts.map {|t| t.match(/.*\/(\S+\.rb)$/)[1]}
    erb :listtests
  end

  before do
  end
end
