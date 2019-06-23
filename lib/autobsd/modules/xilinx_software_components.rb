class Autobsd::Modules::XilinxSoftwareComponents
  def initialize(builder, config)
    @builder = builder
    @config = config
  end

  def build!
    project_name = @config.fetch "project"
    build_dir = "#{@builder.root}/VivadoWorkspace/#{project_name}-SDK"
    FileUtils.mkpath build_dir

    hardware_definition = @builder.exports.fetch(project_name)
    regenerate_project = false

    sdk = @builder.config.fetch "xilinx_sdk"

    if File.exist? "#{build_dir}/fsbl_dir/Makefile"
      regenerate_project = File.mtime("#{build_dir}/fsbl_dir/Makefile") < File.mtime(hardware_definition)
    else
      regenerate_project = true
    end

    if regenerate_project
      @builder.logger.info "Regenerating Xilinx software components"

      FileUtils.copy hardware_definition, "#{build_dir}/#{project_name}.hdf", preserve: true

      File.write "#{build_dir}/generate.tcl", <<EOF
  set hwdsgn [ hsi::open_hw_design "#{project_name}.hdf" ]

  hsi::set_repo_path "#{@builder.root}/projects/device-tree-xlnx"
  hsi::create_sw_design device-tree -os device_tree -proc ps7_cortexa9_0
  #{File.read "#{@builder.root}/projects/#{project_name}/devicetree_conf.tcl"}
  hsi::generate_target -dir "#{build_dir}/dts_dir"

  hsi::generate_app -hw $hwdsgn -os standalone -proc ps7_cortexa9_0 -app zynq_fsbl -compile -sw fsbl -dir "#{build_dir}/fsbl_dir"
EOF

      @builder.host_execute_checked "#{sdk}/bin/xsct", "generate.tcl", chdir: build_dir
    end

    @builder.logger.info "Building Xilinx software components"

    File.write "#{build_dir}/build.cmd", <<EOF
call #{sdk}/settings64.bat
set RDI_PLATFORM=win
make -C fsbl_dir
EOF
    @builder.host_execute_checked "build.cmd", chdir: build_dir

    @builder.logger.info "Regenerating device tree"

    path = [ "#{build_dir}/dts_dir" ]
    device_tree = expand_dts_file("#{@builder.root}/projects/#{project_name}/#{project_name}.dts", path)
    File.write "#{build_dir}/#{project_name}.dts", device_tree

    exit_code = nil
    compiled_tree = "".force_encoding("BINARY")

    channel = @builder.ssh_session.open_channel do |channel|
      channel.exec "/root/obj/root/src/tmp/obj-tools/usr.bin/dtc/dtc" do |ch, success|
        unless success
          raise "could not execute DTC"
        end

        channel.on_request "exit-status" do |ch2, data|
          exit_code = data.read_long
        end

        channel.on_request "exit-signal" do |ch2, data|
          exit_code = 128 + data.read_long
        end

        channel.on_data do |ch2, data|
          compiled_tree << data
        end

        channel.on_extended_data do |ch2, type, data|
          @builder.log_command_output :debug, data
        end
      end
    end

    channel.send_data device_tree
    channel.eof!

    channel.wait

    if exit_code != 0
      raise "dtc failed, exit code: #{exit_code}"
    end

    File.binwrite "#{build_dir}/#{project_name}.dtb", compiled_tree

    @builder.exports["#{project_name}-FSBL"] = File.join(build_dir, "fsbl_dir", "executable.elf")
    @builder.exports["#{project_name}-DTB"] = "#{build_dir}/#{project_name}.dtb"
  end

  def expand_dts_file(filename, path)
    contents = File.read(filename)

    @builder.logger.debug "reading #{filename}"

    contents.gsub! /^\/include\/ "(.*)"\s*$/ do
      name = $1
      @builder.logger.debug "include: #{name.inspect}"
      prefix = path.find { |item| File.exist? File.join(item, name) }
      if prefix.nil?
        raise "DTS include file #{name}, referenced by #{filename}, is not found"
      end

      expand_dts_file File.join(prefix, name), path
    end

    contents
  end
end
