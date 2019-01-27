class Autobsd::Modules::HostCMakeProject
  def initialize(builder, config)
    @builder = builder
    @config = config

    project = @config.fetch("project")
    @source_dir = File.join(@builder.root, "projects", project)
    @build_dir = File.join(@builder.root, "HostBuild", project)
  end

  def build!
    extra = []

    if @builder.config.include? "host_generator"
      extra.push "-G"
      extra.push @builder.config["host_generator"]
    end

    FileUtils.mkpath @build_dir
    @builder.host_execute_checked "cmake", @source_dir, *extra, chdir: @build_dir

    cores = @builder.config.fetch("cores")
    @builder.host_execute_checked "cmake", "--build", @build_dir, "-j", cores.to_s, "--config", @config.fetch("configuration")

  end
end
