class Autobsd::Modules::FreeBSDSystem
  SRC_PATH = "/root/src"
  OBJ_PATH = "/root/obj"
  WORLD_PATH = "/root/world"
  SRC_CONF = "/root/src.conf"
  MAKE_CONF = "/root/make.conf"

  def initialize(builder, config)
    @builder = builder
    @config = config
  end

  def build!
    #establish_svn
    #sync_sources
    #build_world
    build_modules

    @builder.execute_checked "ln", "-sf", "#{OBJ_PATH}#{SRC_PATH}/tmp/usr/bin/as", "/usr/bin/#{@builder.config.fetch("cmake_target")}-as"

    FileUtils.mkpath File.join(@builder.root, "TargetOutputs")
    kernel_path = File.join @builder.root, "TargetOutputs", "kernel"
    @builder.sftp_session.download! "#{WORLD_PATH}/boot/kernel/kernel", kernel_path
    @builder.exports["kernel"] = kernel_path

    @config.fetch("modules").each do |mod|
      module_path = File.join @builder.root, "TargetOutputs", mod
      @builder.sftp_session.download! "#{WORLD_PATH}/boot/modules/#{mod}", module_path
      @builder.exports[mod] = module_path
    end
  end

  def sync_sources
    host_source_dir = File.join @builder.root, "projects", "FreeBSDKernelOverlay"
    target_source_dir = SRC_PATH

    files = []
    directories = Set[]

    directories.add target_source_dir

    Dir["#{host_source_dir}/**/*"].each do |file|
      path = file[(host_source_dir.size + 1)..-1]

      directory = File.dirname(path)
      unless directory == "."
        directories.add File.join(target_source_dir, directory)
      end

      stat = File.stat file

      if stat.file?
        files.push [ path, stat ]
      end
    end

    directories.each do |dir|
      begin
        @builder.sftp_session.mkdir! dir
      rescue Net::SFTP::StatusException

      end
    end

    files.each do |path, stat|
      remote_path = File.join SRC_PATH, path

      attributes =
          begin
            @builder.sftp_session.stat! remote_path
          rescue Net::SFTP::StatusException => e
            nil
          end

      same =
        if attributes.nil?
          false
        else
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

          same
        end

      unless same
        @builder.logger.info "Copying #{path}"

        @builder.sftp_session.upload!(
          File.join(host_source_dir, path),
          remote_path
        )

        @builder.sftp_session.setstat! remote_path,
          atime: stat.atime.tv_sec,
          atime_nseconds: stat.atime.tv_nsec,
          ctime: stat.ctime.tv_sec,
          ctime_nseconds: stat.ctime.tv_nsec,
          mtime: stat.mtime.tv_sec,
          mtime_nseconds: stat.mtime.tv_nsec
      end
    end
  end

  def build_world
    @builder.execute "kldload", "filemon"

    @builder.sftp_session.upload! @builder.path_to_file(@config.fetch("src_conf")), SRC_CONF
    @builder.sftp_session.upload! @builder.path_to_file(@config.fetch("make_conf")), MAKE_CONF

    @builder.logger.info "Building world"

    @builder.execute_checked "make",
      "-C", SRC_PATH,
      "TARGET=#{target}",
      "TARGET_ARCH=#{target_arch}",
      "MAKEOBJDIRPREFIX=#{OBJ_PATH}",
      "__MAKE_CONF=#{MAKE_CONF}",
      "SRCCONF=#{SRC_CONF}",
      "WITH_META_MODE=yes",
      "WITHOUT_WARNS=1",
      "-j#{cores}", "buildworld"

    @builder.execute_checked "make",
      "-C", SRC_PATH,
      "TARGET=#{target}",
      "TARGET_ARCH=#{target_arch}",
      "MAKEOBJDIRPREFIX=#{OBJ_PATH}",
      "__MAKE_CONF=#{MAKE_CONF}",
      "SRCCONF=#{SRC_CONF}",
      "WITH_META_MODE=yes",
      "DESTDIR=#{WORLD_PATH}",
      "installworld"

    @builder.execute_checked "make",
      "-C", SRC_PATH,
      "TARGET=#{target}",
      "TARGET_ARCH=#{target_arch}",
      "MAKEOBJDIRPREFIX=#{OBJ_PATH}",
      "__MAKE_CONF=#{MAKE_CONF}",
      "SRCCONF=#{SRC_CONF}",
      "WITH_META_MODE=yes",
      "KERNCONF=#{kernel_config}",
      "-j#{cores}", "buildkernel"

    @builder.execute_checked "make",
      "-C", SRC_PATH,
      "TARGET=#{target}",
      "TARGET_ARCH=#{target_arch}",
      "MAKEOBJDIRPREFIX=#{OBJ_PATH}",
      "__MAKE_CONF=#{MAKE_CONF}",
      "SRCCONF=#{SRC_CONF}",
      "WITH_META_MODE=yes",
      "DESTDIR=#{WORLD_PATH}",
      "KERNCONF=#{kernel_config}",
      "installkernel"
  end

  def target
    @config.fetch("target")
  end

  def target_arch
    @config.fetch("target_arch")
  end

  def cores
    @builder.config.fetch("cores")
  end

  def kernel_config
    @config.fetch("kernel_config")
  end

  def build_modules
    build_script = StringIO.new

    build_script.puts "#!/bin/sh"
    build_script.puts "set -e"

    @config.fetch("module_projects").each do |mod|
      project = mod["name"]
      target_directory = "/root/projects/#{project}"
      @builder.sync_directory_twoway File.join(@builder.root, "projects", project), target_directory

      mod.fetch("interface_headers", []).each do |header|
        @builder.sftp_session.upload!(
          @builder.exports.fetch(header + ".h"),
          "#{target_directory}/#{header}.h"
        )
      end

      build_script.puts "echo Starting build for #{project}"
      build_script.puts "make -C #{target_directory} -j#{cores}"
      build_script.puts "make -C #{target_directory} install"
    end

    build_script.rewind

    @builder.sftp_session.upload!(
      build_script,
      "/root/buildmodules.sh"
    )

    @builder.sftp_session.setstat! "/root/buildmodules.sh", permissions: 0755

    @builder.execute_checked "make",
      "-C", SRC_PATH,
      "TARGET=#{target}",
      "TARGET_ARCH=#{target_arch}",
      "MAKEOBJDIRPREFIX=#{OBJ_PATH}",
      "__MAKE_CONF=#{MAKE_CONF}",
      "SRCCONF=#{SRC_CONF}",
      "WITH_META_MODE=yes",
      "DESTDIR=#{WORLD_PATH}",
      "KERNCONF=#{kernel_config}",
      "BUILDENV_SHELL=/root/buildmodules.sh",
      "buildenv"

  end

  def establish_svn

    branch = @config.fetch("branch")
    revision = @config.fetch("revision").to_s

    svn_missing = false

    @builder.logger.info "Checking FreeBSD SVN repository status"

    result = @builder.execute_capturing "svnlite", "info", SRC_PATH

    if result.exitstatus != 0
      @builder.logger.info "Releasing locks"

      result = @builder.execute "svnlite", "cleanup", SRC_PATH

      if result.exitstatus != 0
        svn_missing = true
      else
        result = @builder.execute_capturing "svnlite", "info", SRC_PATH
      end
    end

    if !svn_missing && result.exitstatus != 0
      svn_missing = true
    end

    if svn_missing
      @builder.execute_checked "svnlite", "checkout", branch, "-r", revision, SRC_PATH
    else
      repo_info = {}
      result.split("\n").each do |line|
        key, value = line.split(": ")
        repo_info[key] = value
      end

      if repo_info["URL"] != branch
        @builder.logger.info "Changing repository root"

        @builder.execute_checked "svnlite", "switch", "-r", revision, branch, SRC_PATH
      end

      if repo_info["Revision"] != revision
        @builder.logger.info "Changing revision"

        @builder.execute_checked "svnlite", "update", "-r", revision, SRC_PATH
      end

      result = @builder.execute_capturing_checked "svnlite", "status", "--depth", "immediates", SRC_PATH
      if result =~ /^!/
        @builder.logger.info "Update/checkout was interrupted, restarting"

        @builder.execute_checked "svnlite", "update", "-r", revision, SRC_PATH
      end
    end
  end
end
