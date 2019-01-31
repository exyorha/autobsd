class Autobsd::Modules::BSDFilesystem
  def initialize(builder, config)
    @builder = builder
    @config = config
  end

  def build!
    name = @config.fetch "image_name"

    [ "/root/FSBuild", "/root/FSBuild/#{name}" ].each do |dir|
      begin
        @builder.sftp_session.mkdir! dir
      rescue Net::SFTP::StatusException

      end
    end

    path = "/root/FSBuild/#{name}"

    manifest = File.read @builder.path_to_file @config.fetch('manifest')
    manifest.gsub!(/%(.+?)%/) { @builder.exports.fetch $1 }

    stream = StringIO.new manifest

    @builder.sftp_session.upload! stream, "#{path}/manifest"

    @builder.execute_checked "makefs", "-t", "cd9660",
      "-o", "allow-deep-trees",
      "-o", "allow-illegal-chars",
      "-o", "allow-max-name",
      "-o", "allow-multidot",
      "-o", "isolevel=2",
      "-o", "rockridge",
      "-o", "verbose",
      "#{path}/#{name}", "#{path}/manifest"

      @builder.execute_checked "mkuzip",
        "-S", "-d", "-Z", "-o", "#{path}/#{name}_compressed", "#{path}/#{name}"

      FileUtils.mkpath File.join(@builder.root, "TargetOutputs")
      local_path = File.join @builder.root, "TargetOutputs", name
      @builder.sftp_session.download! "#{path}/#{name}_compressed", local_path
      @builder.exports[name] = local_path
  end
end
