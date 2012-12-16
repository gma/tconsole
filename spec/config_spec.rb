require 'spec_helper'

describe TConsole::Config do
  context "a Config without arguments" do
    before do
      @config = TConsole::Config.new([])
    end

    context "when configured test directory doesn't exist" do
      before do
        @config.test_dir = "./monkey_business"
      end

      it "sets a validation error" do
        expect(@config.validation_errors[0]).to eq("Couldn't find test directory `./monkey_business`. Exiting.")
      end
    end

    context "when the configuration doesn't include an all file set" do
      before do
        @config.file_sets = {}
      end

      it "sets a validation error" do
        expect(@config.validation_errors[0]).to eq("No `all` file set is defined in your configuration. Exiting.")
      end
    end
  end

  context "a Config with the trace argument" do
    before do
      @config = TConsole::Config.new(Shellwords.shellwords("--trace"))
    end

    it "has tracing enabled" do
      expect(@config.trace_execution).to be_true
    end
  end

  context "a Config with the once argument" do
    before do
      @config = TConsole::Config.new(Shellwords.shellwords("--once all"))
    end

    it "has run once enabled" do
      expect(@config.once).to be_true
    end
  end

  context "a Config with remaining arguments" do
    before do
      @config = TConsole::Config.new(Shellwords.shellwords("--trace set fast on"))
    end

    it "sets remaining args as first command" do
      expect(@config.run_command).to eq("set fast on")
    end
  end

  describe ".run" do
    before do
      TConsole::Config.run do |config|
        config.test_dir = "./awesome_sauce"
      end
    end

    after do
      TConsole::Config.clear_loaded_configs
    end

    it "saves the run proc" do
      loaded_configs = TConsole::Config.instance_variable_get(:@loaded_configs)
      expect(loaded_configs.length).to eq(1)
    end

    it "runs loaded configs from first to last" do
      TConsole::Config.run do |config|
        config.test_dir = "./awesomer_sauce"
      end

      config = TConsole::Config.configure
      expect(config.test_dir).to eq("./awesomer_sauce")
    end
  end

  describe ".load_config" do
    it "loads configs" do
      TConsole::Config.load_config(File.join(File.dirname(__FILE__), "sample_config"))
      loaded_configs = TConsole::Config.instance_variable_get(:@loaded_configs)
      expect(loaded_configs.length).to eq(1)
    end
  end
end
