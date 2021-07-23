require 'socket'
require 'active_support/all'
require 'rack'
require 'rack/lobster'
require 'pry'
require_relative 'request'
require_relative 'response'

require 'rails'
require 'action_controller/railtie'

class SingleFile < Rails::Application
  config.session_store :cookie_store, :key => '_session'
  config.secret_key_base = '78903asd24b234asd2asdasuiv4uasdas4u32v423ty432'
  Rails.logger = Logger.new($stdout)
end

class PagesController < ActionController::Base
  def index
    render inline: '<h1>Hello World<h1>'
  end
end

SingleFile.routes.draw do
  root to: 'pages#index'
end

APP = SingleFile
port = ENV.fetch('PORT', 2000).to_i
server = TCPServer.new port

puts "Listening on port #{port}.."

def render(file:)
  body = File.binread(file)
  Response.new(
    code: 200,
    body: body,
    headers: {
      'Content-Type': 'text/html',
      'Content-Length': body.length
    }
  )
end

def template_exists?(path)
  File.exist?(path)
end

def route(request, client)
  path = request.path == '/' ? 'index.html' : request.path
  full_path = File.join(__dir__, 'views', path)
  # rack application will render every route that does not match a file
  if template_exists?(full_path)
    render file: full_path
  else
    status, headers, body = APP.call({
                                       'REQUEST_METHOD' => request.method,
                                       'PATH_INFO' => request.path,
                                       'QUERY_STRING' => request.query,
                                       'SERVER_NAME' => 'localhost',
                                       'SERVER_HOST' => 2000,
                                       'HTTP_HOST' => 'localhost',
                                       'rack.input' => client
                                     })
    Response.new(code: status, body: body.join, headers: headers)
  end
rescue => e
  puts e.full_message
  Response.new(code: 500)
end

loop do
  Thread.start(server.accept) do |client|
    request = Request.new client.readpartial(2048)

    response = route(request, client)

    response.send(client)

    client.close
  end
end
