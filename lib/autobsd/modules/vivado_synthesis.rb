class Autobsd::Modules::VivadoSynthesis
	def initialize(builder, config)
		@builder = builder
		@config = config
		@project_name = config.fetch "project"
		@project_root = File.join @builder.root, "projects", @project_name
		@vivado_root = @builder.config.fetch "vivado"
		@project = File.join @builder.root, "VivadoWorkspace", @project_name, "#{@project_name}.xpr"
		@documentation_root = File.join @builder.root, "documentation", @project_name
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
	reset_run synth_1
	launch_runs synth_1
	wait_on_run synth_1
}

if { [get_property NEEDS_REFRESH [get_runs impl_1]] || [get_property PROGRESS [get_runs impl_1]] ne "100%"  } {
	reset_run impl_1
	launch_runs impl_1 -to_step write_bitstream
	wait_on_run impl_1
}
EOF

		@builder.logger.info "Building documentation"

		html_template = nil
		header_template = nil

		Dir[File.join(@project_root, "rtl", "*_interface.v")].each do |filename|
			content = File.read filename, encoding: 'UTF-8'

		  parser = OrigenVerilog::Preprocessor::GrammarParser.new
		  tree = parser.parse content


		  unless tree
		    raise "parse error in #{filename}:#{parser.failure_line}.#{parser.failure_column}: #{parser.failure_reason}"
		  end

		  ast = tree.to_ast

		  processor = RegdocProcessor.new
		  processor.process ast

			if processor.has_any_documentation?
				FileUtils.mkpath @documentation_root

			  xml = processor.to_xml

				xml_filename = "#{processor.interface_name}.xml"
				xml_file = File.join(@documentation_root, xml_filename)
				h_filename = "#{processor.interface_name}.h"
				h_file = File.join(@documentation_root, h_filename)
			  File.open(xml_file, "w") do |outf|
			    xml.write outf
			  end

				if html_template.nil?
					html_template = Nokogiri::XSLT(File.read(File.join(@documentation_root, "../regdoc_style.xsl")))
				end

				if header_template.nil?
					header_template = Nokogiri::XSLT(File.read(File.join(@documentation_root, "../interface_header.xsl")))
				end

				document = Nokogiri::XML(xml.to_s)

				transformed_document = html_template.apply_to(document)

				File.open(File.join(@documentation_root, "#{processor.interface_name}.html"), "w") do |outf|
					outf.write transformed_document
				end

				transformed_document = header_template.apply_to document
				File.open(h_file, "w") do |outf|
					outf.write transformed_document
				end
			end

			@builder.exports[xml_filename] = xml_file
			@builder.exports[h_filename] = h_file
		end

		@builder.logger.info "Exporting hardware"

		@builder.host_execute_checked "#{@vivado_root}/bin/vivado",
			"-mode", "batch",
			"-source", "#{autogen_root}/export.tcl",
			"-nolog", "-nojournal",
			@project,
			chdir: File.dirname(@project)

		@builder.exports[@project_name] = "#{File.dirname(@project)}/#{@project_name}.runs/impl_1/#{root_bd}_wrapper.hwdef"
		@builder.exports[@project_name + ".bit"] = "#{File.dirname(@project)}/#{@project_name}.runs/impl_1/#{root_bd}_wrapper.bit"
	end
end
