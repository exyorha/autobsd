class Autobsd::Modules::BSDBootImage
  def initialize(builder, config)
    @builder = builder
    @config = config
  end

  def build!
    builder = @builder.exports.fetch "BSDBootImageBuilder"

    FileUtils.mkpath File.join(@builder.root, "TargetOutputs")
    image_path = File.join @builder.root, "TargetOutputs", @config.fetch("image_name")

    file = Tempfile.new 'blueprint'
    begin
      blueprint = File.read @builder.path_to_file @config.fetch('blueprint')

      blueprint.gsub!(/%(.+?)%/) { @builder.exports.fetch $1 }

      file.write blueprint

      file.rewind
      file.flush

      @builder.host_execute_checked builder, image_path, file.path
    ensure
      file.close
      file.unlink
    end

  end
end
