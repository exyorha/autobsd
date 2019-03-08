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
set(CMAKE_C_FLAGS "-target #{target} --sysroot=/root/obj/root/src/tmp -B/root/obj/root/src/tmp/usr/bin")
set(CMAKE_CXX_FLAGS "-target #{target} --sysroot=/root/obj/root/src/tmp -B/root/obj/root/src/tmp/usr/bin")
set(CMAKE_ASM_FLAGS "-target #{target} --sysroot=/root/obj/root/src/tmp -B/root/obj/root/src/tmp/usr/bin")
EOF

    @builder.sftp_session.upload!(StringIO.new(toolchain), "/root/toolchain.cmake")

    extra = []

    if has_host_tools
      @builder.execute_checked "cmake", "-S", File.join(@target_source_dir, "HostTools"), "-B", File.join(@target_build_dir, "NativeHostTools")
      @builder.execute_checked "cmake", "--build", File.join(@target_build_dir, "NativeHostTools"), "-j", cores.to_s, "--config", @config.fetch("configuration")

      extra << "-DIMPORT_HOST_TOOLS=#{File.join(@target_build_dir, "NativeHostTools", "ImportHostTools.cmake")}"
    end

    @builder.execute_checked "cmake", "-S", @target_source_dir, "-B", @target_build_dir,
      "-DCMAKE_TOOLCHAIN_FILE=/root/toolchain.cmake",
      *extra

    @builder.execute_checked "cmake", "--build", @target_build_dir, "-j", cores.to_s, "--config", @config.fetch("configuration")

    @config.fetch("retrieve_exports", {}).each do |name, path|
      FileUtils.mkpath File.join(@builder.root, "TargetOutputs")
      local_path = File.join @builder.root, "TargetOutputs", name
      @builder.sftp_session.download! File.join(@target_build_dir, path), local_path
      @builder.exports[name] = local_path
    end
  end

  def cores
    @builder.config.fetch("cores")
  end

  def has_host_tools
    @config.fetch("has_host_tools", false)
  end

  def sync_sources
    @builder.logger.info "Synchronizing project folder: #{@target_source_dir}"

    @builder.sync_directory_twoway @host_source_dir, @target_source_dir
  end

end
