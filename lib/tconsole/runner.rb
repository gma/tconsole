module TConsole
  class Runner

    attr_accessor :config, :reporter, :console, :stty_save

    # Public: Sets up the new runner's config.
    def initialize(argv)
      # try to load the default configs
      Config.load_config(File.join(Dir.home, ".tconsole"))
      Config.load_config(File.join(Dir.pwd, ".tconsole"))
      self.config = Config.configure(argv)
      self.reporter = Reporter.new(config)
    end

    # Spawns a new environment. Looks at the results of the environment to determine whether to stop or
    # keep running
    def run
      prepare_process
      welcome_message
      exit(1) if print_config_errors

      # Set up our console input handling and history
      console = Console.new(@config)

      # Start the server
      while environment_run_loop(console)
        # just need to run the loop
      end

      console.store_history

      cleanup_process
    end

    # Internal: Set up the process and console.
    def prepare_process
      self.stty_save = `stty -g`.chomp

      trap("SIGINT", "IGNORE")
      trap("SIGTSTP", "IGNORE")
    end

    # Internal: Cleans up the process at the end of execution.
    def cleanup_process
      puts
      puts "Exiting. Bye!"
      system("stty", self.stty_save);
    end

    # Internal: Prints the tconsole welcome message.
    def welcome_message
      puts
      puts "Welcome to tconsole (v#{TConsole::VERSION}). Type 'help' for help or 'exit' to quit."
    end

    # Internal: Prints config errors, if there are any.
    #
    # Returns true if there were errors, false otherwise.
    def print_config_errors
      config_errors = @config.validation_errors
      if config_errors.length > 0
        puts
        puts config_errors.first
        true
      else
        false
      end
    end

    # Internal: Environment reload run loop.
    #
    # This run loop handles spawning a new tconsole environment - it's basically
    # just there to handle reloads.
    #
    # Returns false if tconsole needs to stop, true otherwise.
    def environment_run_loop(console)
      pipe_server = PipeServer.new

      reporter.trace("Forking test server.")
      server_pid = fork do
        server_run_loop(pipe_server)
      end

      pipe_server.caller!
      load_environment(pipe_server)

      continue = console.read_and_execute(pipe_server)
      reporter.trace("Console read loop returned - continue: #{continue}")

      Process.waitall

      continue
    end

    # Internal: Asks the server to load the environment.
    #
    # Returns true if the environment was loaded, or false otherwise.
    def load_environment(pipe_server)
      reporter.trace("Attempting to load environment.")
      pipe_server.write({:action => "load_environment"})

      if pipe_server.read
        reporter.trace("Environment loaded successfully.")
        true
      else
        puts "Couldn't load the test environment. Exiting."
        false
      end
    end

    # Internal: Run loop for the server.
    def server_run_loop(pipe_server)
      pipe_server.callee!
      server = Server.new(config, reporter)

      while message = pipe_server.read
        reporter.trace("Server Received Message: #{message[:action]}")
        begin
          result = server.handle(message)
          pipe_server.write(result)
        rescue => e
          puts
          puts "An error occured: #{e.message}"
          reporter.trace("===========")
          reporter.trace(e.backtrace.join("\n"))
          reporter.trace("===========")
          pipe_server.write(nil)
        end
      end
    end
  end
end

