class Autobsd::Modules::FreeBSDSystem
  SRC_PATH = "/root/src"
  OBJ_PATH = "/root/obj"
  WORLD_PATH = "/root/world"
  SRC_CONF = "/root/src.conf"
  MAKE_CONF = "/root/make.conf"

  def initialize(builder)
    @builder = builder
  end

  def build!
    establish_svn
    build_world

  end

  def build_world
    @builder.sftp_session.upload! @builder.path_to_file(@builder.config.fetch("freebsd_src_conf")), SRC_CONF
    @builder.sftp_session.upload! @builder.path_to_file(@builder.config.fetch("freebsd_make_conf")), MAKE_CONF

    @builder.logger.info "Building world"

    target = @builder.config.fetch("freebsd_target")
    target_arch = @builder.config.fetch("freebsd_target_arch")
    cores = @builder.config.fetch("cores")
    kernel_config = @builder.config.fetch("freebsd_kernel_config")

    @builder.execute_checked "make",
      "-C", SRC_PATH,
      "TARGET=#{target}",
      "TARGET_ARCH=#{target_arch}",
      "MAKEOBJDIRPREFIX=#{OBJ_PATH}",
      "__MAKE_CONF=#{MAKE_CONF}",
      "SRCCONF=#{SRC_CONF}",
      "WITH_META_MODE=yes",
      "WITHOUT_WARNS=1",
      "-j#{cores}", "buildworld"

    @builder.execute_checked "make",
      "-C", SRC_PATH,
      "TARGET=#{target}",
      "TARGET_ARCH=#{target_arch}",
      "MAKEOBJDIRPREFIX=#{OBJ_PATH}",
      "__MAKE_CONF=#{MAKE_CONF}",
      "SRCCONF=#{SRC_CONF}",
      "WITH_META_MODE=yes",
      "DESTDIR=#{WORLD_PATH}",
      "installworld"

    @builder.execute_checked "make",
      "-C", SRC_PATH,
      "TARGET=#{target}",
      "TARGET_ARCH=#{target_arch}",
      "MAKEOBJDIRPREFIX=#{OBJ_PATH}",
      "__MAKE_CONF=#{MAKE_CONF}",
      "SRCCONF=#{SRC_CONF}",
      "WITH_META_MODE=yes",
      "KERNCONF=#{kernel_config}",
      "-j#{cores}", "buildkernel"

    @builder.execute_checked "make",
      "-C", SRC_PATH,
      "TARGET=#{target}",
      "TARGET_ARCH=#{target_arch}",
      "MAKEOBJDIRPREFIX=#{OBJ_PATH}",
      "__MAKE_CONF=#{MAKE_CONF}",
      "SRCCONF=#{SRC_CONF}",
      "WITH_META_MODE=yes",
      "DESTDIR=#{WORLD_PATH}",
      "KERNCONF=#{kernel_config}",
      "installkernel"

  end

  def establish_svn

    branch = @builder.config.fetch("freebsd_branch")
    revision = @builder.config.fetch("freebsd_revision").to_s

    svn_missing = false

    @builder.logger.info "Checking FreeBSD SVN repository status"

    result = @builder.execute_capturing "svnlite", "info", SRC_PATH

    if result.exitstatus != 0
      @builder.logger.info "Releasing locks"

      result = @builder.execute "svnlite", "cleanup", SRC_PATH

      if result.exitstatus != 0
        svn_missing = true
      else
        result = @builder.execute_capturing "svnlite", "info", SRC_PATH
      end
    end

    if !svn_missing && result.exitstatus != 0
      svn_missing = true
    end

    if svn_missing
      @builder.execute_checked "svnlite", "checkout", branch, "-r", revision, SRC_PATH
    else
      repo_info = {}
      result.split("\n").each do |line|
        key, value = line.split(": ")
        repo_info[key] = value
      end

      if repo_info["URL"] != branch
        @builder.logger.info "Changing repository root"

        @builder.execute_checked "svnlite", "switch", "-r", revision, branch, SRC_PATH
      end

      if repo_info["Revision"] != revision
        @builder.logger.info "Changing revision"

        @builder.execute_checked "svnlite", "update", "-r", revision, SRC_PATH
      end

      result = @builder.execute_capturing_checked "svnlite", "status", "--depth", "immediates", SRC_PATH
      if result =~ /^!/
        @builder.logger.info "Update/checkout was interrupted, restarting"

        @builder.execute_checked "svnlite", "update", "-r", revision, SRC_PATH
      end
    end
  end
end
