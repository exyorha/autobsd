class Autobsd::Modules::ZynqBootImage
  def initialize(builder, config)
    @builder = builder
    @config = config
  end

  def build!
    FileUtils.mkpath File.join(@builder.root, "TargetOutputs")
    image_path = File.join @builder.root, "TargetOutputs", @config.fetch("image_name")

    file = Tempfile.new 'config'
    begin
      config = File.read @builder.path_to_file @config.fetch('config')

      config.gsub!(/%(.+?)%/) { @builder.exports.fetch $1 }

      file.write config

      file.rewind
      file.flush

      @builder.host_execute_checked "#{@builder.config.fetch("xilinx_sdk")}/bin/bootgen", "-arch", "zynq", "-p", @config.fetch("part"), "-image", file.path, "-w", "on", "-o", image_path
    ensure
      file.close
      file.unlink
    end
    
    @builder.exports[@config.fetch("image_name")] = image_path
  end
end
