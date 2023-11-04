class MailListInlineTag < Liquid::Tag
    def initialize(tag_name, input, tokens)
      super
      @input = input
    end
  
    def lookup(context, name)
      lookup = context
      name.split(".").each { |value| lookup = lookup[value] }
      lookup
    end
  
    def render(context)
      file_path = File.join(Dir.pwd, '_includes', 'maillist.html')
      if File.exist?(file_path)
        content = File.read(file_path)
        content.strip
      else
        "File not found: #{file_path}"
      end
    end
    
    def split_params(params)
      params.split("|")
    end
  end
  
  Liquid::Template.register_tag('maillist', MailListInlineTag)