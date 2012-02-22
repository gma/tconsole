require "tconsole/version"
require "tconsole/config"
require "tconsole/console"
require "tconsole/server"
require "tconsole/pipe_server"
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

        pipe_server = PipeServer.new

        config.trace("Forking test server.")
        server_pid = fork do
          pipe_server.callee!

          begin
            server = Server.new(config)

            while message = pipe_server.read
              config.trace("Server Received Message: #{message[:action]}")
              pipe_server.write(server.handle(message))
            end

          rescue Interrupt
            # do nothing here since the outer process will shut things down for us
          end
        end

        pipe_server.caller!

        wait_until = Time.now + 10

        config.trace("Attempting to load environment.")
        pipe_server.write({:action => "load_environment"})

        unless pipe_server.read
          puts "Couldn't load the test environment. Exiting."
          exit(1)
        end
        config.trace("Environment loaded successfully.")

        running = console.read_and_execute(pipe_server)

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


