#!/usr/bin/env ruby

require "drb/drb"

class Server
  def load_environment
    puts "This is me pretending to load the environment."

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
    running = server.load_environment
    loaded = true
  rescue => e
    puts e.message
    puts e.backtrace.join("\n")
    puts
    puts

    sleep(1)
  end
end

if !loaded
  puts "Wasn't able to connect"
else
  puts "Connected!"
  server.stop
end
