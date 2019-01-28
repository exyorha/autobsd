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
				"-nolog", "-nojournal",
				"-tclargs", "--origin_dir", @project_root,
				chdir: File.join(@builder.root, "VivadoWorkspace")
		end

		autogen_root = File.join(File.dirname(@project), "autobsd")

		FileUtils.mkpath autogen_root
		File.write "#{autogen_root}/export.tcl", <<EOF
if { [get_property NEEDS_REFRESH [get_runs synth_1]] } {
	launch_runs synth_1
	wait_on_run synth_1
}

if { [get_property NEEDS_REFRESH [get_runs impl_1]] } {
	launch_runs impl_1
	wait_on_run impl_1
}

write_hwdef -force #{autogen_root}/#{@project_name}.hdf
EOF

		@builder.logger.info "Exporting hardware"

		@builder.host_execute_checked "#{@vivado_root}/bin/vivado",
			"-mode", "batch",
			"-source", "#{autogen_root}/export.tcl",
			"-nolog", "-nojournal",
			@project,
			chdir: File.dirname(@project)

		@builder.exports[@project_name] = "#{autogen_root}/#{@project_name}.hdf"
	end
end
