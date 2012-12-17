module TConsole
  class Runner

    attr_accessor :config, :running, :console, :stty_save

    # Public: Sets up the new runner's config.
    def initialize(argv)
      # try to load the default configs
      Config.load_config(File.join(Dir.home, ".tconsole"))
      Config.load_config(File.join(Dir.pwd, ".tconsole"))
      @config = Config.configure(argv)

      # Set up our running variable
      self.running = true
    end

    # Spawns a new environment. Looks at the results of the environment to determine whether to stop or
    # keep running
    def run
      running = true
      welcome_message
      exit(1) if print_config_errors

      # Set up our console input handling and history
      console = Console.new(@config)

      # Start the server
      while running
        environment_run_loop(console)
      end
      console.store_history

      puts
      puts "Exiting. Bye!"
      system("stty", stty_save);
    end

    # Set up the process and console.
    def prepare_process
      self.stty_save = `stty -g`.chomp

      trap("SIGINT", "IGNORE")
      trap("SIGTSTP", "IGNORE")
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
    def environment_run_loop(console)
      pipe_server = PipeServer.new

      config.trace("Forking test server.")
      server_pid = fork do
        server_run_loop(pipe_server)
      end

      pipe_server.caller!

      load_environment

      process_command

      Process.waitall
    end

    # Internal: Asks the server to load the environment.
    #
    # Returns true if the environment was loaded, or false otherwise.
    def load_environment
      config.trace("Attempting to load environment.")
      pipe_server.write({:action => "load_environment"})

      if pipe_server.read
        config.trace("Environment loaded successfully.")
        true
      else
        puts "Couldn't load the test environment. Exiting."
        false
      end
    end

    # Internal: Run loop for the server.
    def server_run_loop(pipe_server)
      pipe_server.callee!

      server = Server.new(config)

      while message = pipe_server.read
        config.trace("Server Received Message: #{message[:action]}")
        begin
          result = server.handle(message)
          pipe_server.write(result)
        rescue => e
          puts
          puts "An error occured: #{e.message}"
          config.trace("===========")
          config.trace(e.backtrace.join("\n"))
          config.trace("===========")
          pipe_server.write(nil)
        end
      end
    end

    # Internal: Prompts for commands and runs them until exit or relaod
    # is issued.
    def process_commands
      console.pipe_server = pipe_server
      self.running = console.read_and_execute
      console.pipe_server = nil
    end
  end
end

