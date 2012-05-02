# Load the Sinatra app
require "#{File.dirname(__FILE__)}/../lib/collectd-plot"
require 'rspec'
require 'rack/test'
require 'collectd-plot'
require 'collectd-plot/config'

set :environment, :test

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

def app
  CollectdPlot::Service
end
