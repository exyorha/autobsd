class RegdocProcessor
  include AST::Processor::Mixin

  attr_reader :defines, :interface_name

  def initialize
    @defines = {}
    @interface_name = nil
    @interface_doc = []
    @unbound_documentation = nil
    @has_any_documentation = false
  end

  def has_any_documentation?
    @has_any_documentation
  end

  def doc_into_element(element, documentation)
    return if documentation.empty?

    documentation = documentation.join("\n")

    doc = Kramdown::Document.new documentation

    html = doc.to_html
    html_doc = REXML::Document.new("<body>#{html}</body>")

    html_doc.root.children.each do |child|
      if child.is_a? REXML::Element
        child.add_namespace "http://www.w3.org/1999/xhtml"
      end

      element.add child
    end
  end

  def convert_verilog_number(num)
    unless num =~ /\A([0-9]*'[sS]?([bBoOhHdD]))(-?[0-9a-fA-F]+)\Z/
      raise "malformed number in Verilog: #{num}"
    end

    radix =
      if $1.nil?
        10
      else
        case $2
        when 'b', 'B'
          2

        when 'o', 'O'
          8

        when 'h', 'H'
          16

        when 'd', 'D'
          10
        end
      end

    Integer($3, radix)
  end

  def to_xml
    if @has_any_documentation && !@interface_name
      raise "Documentation is present, but no interface name is specified"
    end

    doc = REXML::Document.new
    doc.add REXML::XMLDecl.new

    regdoc = REXML::Element.new 'regdoc'
    doc.add regdoc

    peripheral = REXML::Element.new 'peripheral'
    regdoc.add peripheral
    peripheral.attributes['name'] = @interface_name

    doc_into_element peripheral, @interface_doc

    reg_prefix = "#{@interface_name}_REG_"

    @defines.each do |name, define|
      if name.start_with? reg_prefix
        reg_name = name[reg_prefix.size..-1]

        register = REXML::Element.new 'register'
        register.attributes['name'] = reg_name
        register.attributes['offset'] = "0x" + (convert_verilog_number(define.value) * 4).to_s(16)
        peripheral.add register

        doc_into_element register, define.documentation

        reg_field_prefix = "#{@interface_name}_#{reg_name}_"

        @defines.each do |fname, fdefine|
          if fname.start_with? reg_field_prefix
            field_name = fname[reg_field_prefix.size..-1]

            field = REXML::Element.new 'field'
            field.attributes["name"] = field_name

            register.add field

            if fdefine.value =~ /\A([0-9]+):([0-9]+)\Z/
              field.attributes["last"] = $1
              field.attributes["first"] = $2
            else
              val = Integer(fdefine.value, 10)
              field.attributes["last"] = val.to_s
              field.attributes["first"] = val.to_s
            end

            doc_into_element field, fdefine.documentation
          end
        end
      end
    end

    doc
  end

  def on_source(node)
    process_all node.children
  end

  def on_comment(comment)
     text, = *comment

     return unless text.start_with?("/*!") || text.start_with?("//!")

     lines = text.split("\n")[1..-2]

     lines.each do |line|
       line.gsub! /\A\s+\* ?/, ""
     end

     process_comment lines
  end

  def on_define(define)
    namenode, textnode = *define
    name, = *namenode
    text, = *textnode

    define = RegdocDefine.new name, text

    unless @unbound_documentation.nil?
      define.documentation = @unbound_documentation
      @unbound_documentation = nil
    end

    @defines[name] = define
  end

  def process_comment(lines)
    recipient = nil

    @has_any_documentation = true

    lines.each do |line|
      if line[0] == '@'
        keyword, *args = line[1..-1].split(" ")

        case keyword
        when "interface"
          @interface_name, = *args
          recipient = @interface_doc

        when "define"
          recipient = @defines.fetch(args[0]).documentation

        else
          raise "unsupported keyword: #{keyword}"
        end
      elsif line.empty? && recipient.nil?
        next
      else
        if recipient.nil?
          unless @unbound_documentation.nil?
            raise "already have unbound documentation on #{line}"
          end

          @unbound_documentation = []
          recipient = @unbound_documentation
        end

        recipient << line
      end
    end
  end

  def on_ifndef(node)
    name, *children = node.children

    process_all children
  end
end
