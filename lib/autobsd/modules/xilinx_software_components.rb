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

    @builder.exports["#{project_name}-FSBL"], File.join(build_dir, "fsbl_dir", "executable.elf")
  end
end
