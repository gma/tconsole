require "tconsole/version"
require "tconsole/config"
require "tconsole/console"
require "tconsole/server"
require "tconsole/test_result"
require "tconsole/util"

require "readline"
require "benchmark"
require "drb/drb"
require "term/ansicolor"
require "shellwords"

module TConsole
  class Runner

    # Spawns a new environment. Looks at the results of the environment to determine whether to stop or
    # keep running
    def self.run(argv)
      stty_save = `stty -g`.chomp

      running = true
      trap("SIGINT", "SYSTEM_DEFAULT")

      # A little welcome
      puts
      puts "Welcome to tconsole (v#{TConsole::VERSION}). Type 'help' for help or 'exit' to quit."

      # set up the config
      config = Config.configure
      config.trace_execution = true if argv.include?("--trace")

      # Set up our console input handling and history
      console = Console.new(config)

      # Start the server
      while running
        # ignore ctrl-c during load, since things can get kind of messy if we don't

        config.trace("Forking test server.")
        server_pid = fork do
          begin
            server = Server.new(config)

            drb_server = DRb.start_service("drbunix:/tmp/tconsole.#{Process.pid}", server)
            DRb.thread.join
          rescue Interrupt
            # do nothing here since the outer process will shut things down for us
          end
        end

        wait_until = Time.now + 10

        # Set up our client connection to the server
        config.trace("Connecting to testing server.")
        DRb.start_service
        server = nil

        loaded = false
        until loaded || Time.now > wait_until
          begin
            server = DRbObject.new_with_uri("drbunix:/tmp/tconsole.#{server_pid}")

            config.trace("Testing connection to test server.")
            loaded = server.connected?
          rescue
            # do nothing
            config.trace("Not connected to server yet. Retrying.")
            sleep(1)
          end
        end

        unless loaded
          puts
          puts "Couldn't connect to the test environment. Exiting."
          exit(1)
        end

        begin
          config.trace("Attempting to load environment.")
          running = server.load_environment
        rescue => e
          config.trace("Could not load environment: #{e.message}")
          config.trace("==== Backtrace ====")
          config.trace(e.backtrace.join("\n"))
          config.trace("==== End Backtrace ====")

          puts "Couldn't load the test environment. Exiting."
          exit(1)
        end

        config.trace("Environment loaded successfully.")

        running = console.read_and_execute(server) if running

        server.stop
        Process.waitall
      end

      console.store_history

      puts
      puts "Exiting. Bye!"
      system("stty", stty_save);
    end
  end
end


