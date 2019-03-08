module Autobsd
  class Builder
    attr_reader :ssh_session, :sftp_session, :config, :logger, :root
    attr_accessor :exports

    def initialize(root, config)
      @root = root
      @config = config
      @logger = Logger.new STDERR

      @ssh_session = nil
      @sftp_session = nil
      @command_output = ""

      @exports = {}

      @modules = @config.fetch("modules").map do |mod|
        config = mod
        if config.kind_of? String
          config = { "name" => config }
        end

        Autobsd::Modules.const_get(mod.fetch("name")).new(self, config)
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

    def host_execute(*command)
      @logger.debug Shellwords.join(command)

      IO.popen(command, "r", err: [ :child, :out ]) do |inf|
        result = false

        until result.nil?
          result =
            begin
              inf.readpartial 8192
            rescue EOFError
              nil
            end

          unless result.nil?
            log_command_output :debug, result
          end
        end
      end

      $?.exitstatus
    end

    def host_execute_checked(*command)
      result = host_execute *command
      if result != 0
        raise "#{command.inspect} failed, exit status #{result}"
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
      @logger.info "Connecting to build host"

      @ssh_session = Net::SSH.start @config.fetch("freebsd_buildmachine"), @config.fetch("freebsd_builduser"),
        config: false,
        non_interactive: true#,
        #logger: @logger

      @sftp_session = Net::SFTP::Session.new(@ssh_session)
      @sftp_session.connect!

      @logger.info "Building"

      @modules.each do |mod|
        mod.build!
      end
    end

    def sync_directory_twoway(source, destination)
      @logger.info "Synchronizing #{destination}"

      files = []
      directories = Set[]

      directories.add "/root/projects"
      directories.add destination

      Dir["#{source}/**/*"].each do |file|
        path = file[(source.size + 1)..-1]

        directory = File.dirname(path)
        unless directory == "."
          directories.add File.join(destination, directory)
        end

        stat = File.stat file

        if stat.file?
          files.push [ path, stat ]
        end
      end

      directories.each do |dir|
        begin
          @sftp_session.mkdir! dir
        rescue Net::SFTP::StatusException

        end
      end

      remote_files = []

      files_to_copy = []
      files_to_delete = []

      @sftp_session.dir.glob(destination, "**/*").each do |filename|
        remote_files.push filename

        local_file = files.find { |(name, stat)| name == filename.name }
        if local_file.nil? && !filename.directory?
          files_to_delete.push filename
        end
      end

      files.each do |(name, stat)|
        remote_file = remote_files.find { |file| file.name == name }

        if remote_file.nil?
          files_to_copy.push [ name, stat ]
        else
          attributes = remote_file.attributes

          same = true

          if attributes.respond_to? :ctime
            if attributes.ctime != stat.ctime.tv_sec
              same = false
            end
          end

          if attributes.respond_to? :ctime_nseconds
            if attributes.ctime_nseconds != stat.ctime.tv_nsec
              same = false
            end
          end

          if attributes.respond_to? :mtime
            if attributes.mtime != stat.mtime.tv_sec
              same = false
            end
          end

          if attributes.respond_to? :mtime_nseconds
            if attributes.ctime_nseconds != stat.mtime.tv_nsec
              same = false
            end
          end

          unless same
            files_to_copy.push [ name, stat ]
          end
        end
      end

      @logger.info "Copying #{files_to_copy.size} files, deleting #{files_to_delete.size} files"

      files_to_copy.each do |(name, stat)|
        target_name = File.join(destination, name)

        @sftp_session.upload!(
          File.join(source, name),
          target_name
        )

        @sftp_session.setstat! target_name,
          atime: stat.atime.tv_sec,
          atime_nseconds: stat.atime.tv_nsec,
          ctime: stat.ctime.tv_sec,
          ctime_nseconds: stat.ctime.tv_nsec,
          mtime: stat.mtime.tv_sec,
          mtime_nseconds: stat.mtime.tv_nsec
      end

      files_to_delete.each do |name|
        @sftp_session.remove! File.join(destination, name.name)
      end
    end
  end
end
