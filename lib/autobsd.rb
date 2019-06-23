require 'bundler/setup'
require 'optparse'
require 'logger'
require 'yaml'
require 'net/ssh'
require 'net/sftp'
require 'shellwords'
require 'tempfile'
require 'treetop/runtime'
require 'ast'
require 'REXML/document'
require 'kramdown'
require 'nokogiri'

require_relative 'autobsd/builder'
require_relative 'autobsd/modules'

module Autobsd
  def self.is_up_to_date(destination, source)
    sourcestat = File.stat source

    destinationstat =
      begin
        File.stat destination
      rescue Errno::ENOENT
        return false
      end

    sourcestat.mtime < destinationstat.mtime
  end
end

root = File.expand_path("..", __FILE__)

if !Autobsd.is_up_to_date("#{root}/generated/verilog.rb", "#{root}/verilog.treetop") || !Autobsd.is_up_to_date("#{root}/generated/preprocessor.rb", "#{root}/preprocessor.treetop")
  require 'treetop/compiler'

  FileUtils.mkpath "#{root}/generated"

  compiler = Treetop::Compiler::GrammarCompiler.new
  compiler.compile "#{root}/verilog.treetop", "#{root}/generated/verilog.rb"
  compiler.compile "#{root}/preprocessor.treetop", "#{root}/generated/preprocessor.rb"
end

require_relative 'generated/verilog'
require_relative 'generated/preprocessor'
require_relative 'autobsd/treetop_patches'
require_relative 'autobsd/regdoc_processor'
require_relative 'autobsd/regdoc_define'
