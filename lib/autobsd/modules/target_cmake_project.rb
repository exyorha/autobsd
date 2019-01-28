class Autobsd::Modules::TargetCMakeProject
  def initialize(builder, config)
    @builder = builder
    @config = config

    project = @config.fetch("project")
    @host_source_dir = File.join(@builder.root, "projects", project)
    @target_source_dir = "/root/projects/#{project}"
    @target_build_dir = File.join("/root/targetbuild", project)
  end

  def build!
    sync_sources

    target = @builder.config.fetch("cmake_target")

    toolchain = <<EOF
set(CMAKE_SYSTEM_NAME FreeBSD)
set(CMAKE_SYSTEM_PROCESSOR #{@builder.config.fetch("cmake_system_processor")})
set(CMAKE_SYSROOT /root/obj/root/src/tmp)
set(CMAKE_C_COMPILER cc)
set(CMAKE_CXX_COMPILER c++)
set(CMAKE_ASM_COMPILER cc)
set(CMAKE_C_FLAGS "-target #{target} --sysroot=/root/obj/root/src/tmp")
set(CMAKE_CXX_FLAGS "-target #{target} --sysroot=/root/obj/root/src/tmp")
set(CMAKE_ASM_FLAGS "-target #{target} --sysroot=/root/obj/root/src/tmp")
EOF

    @builder.sftp_session.upload!(StringIO.new(toolchain), "/root/toolchain.cmake")

    @builder.execute_checked "cmake", "-S", @target_source_dir, "-B", @target_build_dir,
      "-DCMAKE_TOOLCHAIN_FILE=/root/toolchain.cmake"

    cores = @builder.config.fetch("cores")
    @builder.execute_checked "cmake", "--build", @target_build_dir, "-j", cores.to_s, "--config", @config.fetch("configuration")

    @config.fetch("retrieve_exports", {}).each do |name, path|
      FileUtils.mkpath File.join(@builder.root, "TargetOutputs")
      local_path = File.join @builder.root, "TargetOutputs", name
      @builder.sftp_session.download! File.join(@target_build_dir, path), local_path
      @builder.exports[name] = local_path
    end
  end

  def sync_sources
    @builder.logger.info "Synchronizing project folder: #{@target_source_dir}"

    files = []
    directories = Set[]

    directories.add "/root/projects"
    directories.add @target_source_dir

    Dir["#{@host_source_dir}/**/*"].each do |file|
      path = file[(@host_source_dir.size + 1)..-1]

      directory = File.dirname(path)
      unless directory == "."
        directories.add File.join(@target_source_dir, directory)
      end

      stat = File.stat file

      files.push [ path, stat ]
    end

    directories.each do |dir|
      begin
        @builder.sftp_session.mkdir! dir
      rescue Net::SFTP::StatusException

      end
    end

    remote_files = []

    files_to_copy = []
    files_to_delete = []

    @builder.sftp_session.dir.glob(@target_source_dir, "**/*").each do |filename|
      remote_files.push filename

      local_file = files.find { |(name, stat)| name == filename.name }
      if local_file.nil?
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

    @builder.logger.info "Copying #{files_to_copy.size} files, deleting #{files_to_delete.size} files"

    files_to_copy.each do |(name, stat)|
      target_name = File.join(@target_source_dir, name)

      @builder.sftp_session.upload!(
        File.join(@host_source_dir, name),
        target_name
      )

      @builder.sftp_session.setstat! target_name,
        atime: stat.atime.tv_sec,
        atime_nseconds: stat.atime.tv_nsec,
        ctime: stat.ctime.tv_sec,
        ctime_nseconds: stat.ctime.tv_nsec,
        mtime: stat.mtime.tv_sec,
        mtime_nseconds: stat.mtime.tv_nsec
    end

    files_to_delete.each do |name|
      @builder.sftp_session.remove! File.join(@target_source_dir, name.name)
    end
  end

end
