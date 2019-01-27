module Autobsd
  class Builder
    attr_reader :ssh_session, :sftp_session, :config, :logger

    def initialize(root, config)
      @root = root
      @config = config
      @logger = Logger.new STDERR

      @ssh_session = nil
      @sftp_session = nil
      @command_output = ""

      @modules = @config.fetch("modules").map do |mod|
        Autobsd::Modules.const_get(mod).new(self)
      end
    end

    def close
      unless @ssh_session.nil? ||  @ssh_session.closed?
        @ssh_session.close
      end
    end

    def path_to_file(file)
      File.join @root, file
    end

    class StringWithExitstatus < String
      def initialize(str, exitstatus)
        super(str)
        @exitstatus = exitstatus
      end

      attr_reader :exitstatus
    end

    def execute_capturing(*command_words)
      command = Shellwords.shelljoin command_words

      result = ""

      channel = nil

      @logger.debug command

      status = {}

      session_result = @ssh_session.exec! command, status: status do |ch, type, data|
        log_command_output :debug, data
        result << data
      end

      StringWithExitstatus.new(result, status[:exit_code])
    end

    def execute_capturing_checked(*command_words)
      command = Shellwords.shelljoin command_words

      result = ""

      channel = nil

      @logger.debug command

      status = {}

      session_result = @ssh_session.exec! command, status: status do |ch, type, data|
        log_command_output :debug, data
        result << data
      end

      if status[:exit_code] != 0
        raise "#{command.inspect} failed, exit status #{status[:exit_code]}"
      end

      result
    end

    def execute(*command_words)
      command = Shellwords.shelljoin command_words

      @logger.debug command

      status = {}

      @ssh_session.exec! command, status: status do |ch, type, data|
        log_command_output :debug, data
      end

      StringWithExitstatus.new("", status[:exit_code])
    end

    def execute_checked(*command_words)
      command = Shellwords.shelljoin command_words

      @logger.debug command

      status = {}

      @ssh_session.exec! command, status: status do |ch, type, data|
        log_command_output :debug, data
      end

      if status[:exit_code] != 0
        raise "#{command.inspect} failed, exit status #{status[:exit_code]}"
      end
    end

    def log_command_output(type, data)
      @command_output << data
      *lines, @command_output = @command_output.split "\n", -1

      lines.each do |line|
        @logger.send type, line
      end
    end

    def build!
      @ssh_session = Net::SSH.start @config.fetch("freebsd_buildmachine"), @config.fetch("freebsd_builduser"),
        config: false,
        non_interactive: true#,
        #logger: @logger

      @sftp_session = Net::SFTP::Session.new(@ssh_session)
      @sftp_session.connect!

      @modules.each do |mod|
        mod.build!
      end
    end
  end
end
