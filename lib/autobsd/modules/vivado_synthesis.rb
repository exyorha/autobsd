class Autobsd::Modules::VivadoSynthesis
	def initialize(builder, config)
		@builder = builder
		@config = config
		@project_name = config.fetch "project"
		@project_root = File.join @builder.root, "projects", @project_name
		@vivado_root = @builder.config.fetch "vivado"
		@project = File.join @builder.root, "VivadoWorkspace", @project_name, "#{@project_name}.xpr"
	end

	def build!
		unless File.exist? @project
			@builder.logger.info "Recreating vivado project"
			FileUtils.mkpath File.dirname @project
			@builder.host_execute_checked "#{@vivado_root}/bin/vivado",
				"-mode", "batch",
				"-source", "#{@project_root}/#{@project_name}.tcl",
				"-source", "#{@project_root}/postinit.tcl",
				"-nolog", "-nojournal",
				"-tclargs", "--origin_dir", @project_root,
				chdir: File.join(@builder.root, "VivadoWorkspace")
		end

		autogen_root = File.join(File.dirname(@project), "autobsd")

		root_bd = @config.fetch "root_bd"

		FileUtils.mkpath autogen_root
		File.write "#{autogen_root}/export.tcl", <<EOF
open_bd_design [get_files #{root_bd}.bd]
generate_target all [get_files #{root_bd}.bd]

if { [get_property NEEDS_REFRESH [get_runs synth_1]] || [get_property PROGRESS [get_runs synth_1]] ne "100%" } {
	launch_runs synth_1
	wait_on_run synth_1
}

if { [get_property NEEDS_REFRESH [get_runs impl_1]] || [get_property PROGRESS [get_runs impl_1]] ne "100%"  } {
	launch_runs impl_1 -to_step write_bitstream
	wait_on_run impl_1
}
EOF

		@builder.logger.info "Exporting hardware"

		@builder.host_execute_checked "#{@vivado_root}/bin/vivado",
			"-mode", "batch",
			"-source", "#{autogen_root}/export.tcl",
			"-nolog", "-nojournal",
			@project,
			chdir: File.dirname(@project)

		@builder.exports[@project_name] = "#{File.dirname(@project)}/#{@project_name}.runs/impl_1/#{root_bd}_wrapper.sysdef"
	end
end
