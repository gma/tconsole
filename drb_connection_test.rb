#!/usr/bin/env ruby

require "drb/drb"

class Server
  def connected?
    true
  end

  def load_environment
    ENV['RAILS_ENV'] ||= "test"

    require './config/application'

    ::Rails.application
    ::Rails::Engine.class_eval do
      def eager_load!
        # turn off eager_loading
      end
    end

    true
  end

  def stop
    DRb.stop_service
  end
end

socket = "/tmp/test.#{Process.pid}"

server_pid = fork do
  server = Server.new

  drb_server = DRb.start_service("drbunix:#{socket}", server)
  DRb.thread.join
end

wait_until = Time.now + 10
DRb.start_service

loaded = false
until loaded || Time.now > wait_until
  begin
    puts "Trying to load environment"
    server = DRbObject.new_with_uri("drbunix:#{socket}")
    loaded = server.connected?
  rescue
    puts "Couldn't connect. Waiting."
    sleep(1)
  end
end

if !loaded
  puts "Wasn't able to connect"
end

puts "Connected! Attempting to load environment"
server.load_environment
puts "Environment loaded!"

# Clean it all up
server.stop
