require 'json'
require 'time'
require 'pry-byebug'
require 'active_support/inflector'
# require 'nokogiri'

## 
# bundle exec ruby json_to_xml.rb Rick\ and\ Morty.json; cat Rick\ and\ Morty.xml | xmllint --format -

def run
  filepath = ARGV[0]
  file = File.new(filepath, "r")
  json = JSON.load(file)

  xml = nil
  ext = File.extname(filepath)
  if ext == 'json'
    if json['thread']
      xml = make_tag('root') do
        recurse(json['thread'], 1, 'items')
      end
    elsif ["http://twitter.com", 'reddit'].any? { |s| json['source'].downcase.include? s }
      xml = make_tag('root') do
        recurse([json], 1, 'items')
      end
    end
  elsif ext == 'csv'
    make_tag('root') do
      CSV.read(filepath, headers: true).reduce do |_,row|
        _ + recurse(row.to_h.select { |k,_| !k.nil? }) # remove nil keys
      end
    end
  end
      
  filename = File.basename(filepath, ext)
  File.write("#{filename}.xml", xml)
end

def recurse(o, depth=0, tag=nil, parent=nil)
  if o.is_a?(Hash)
    out = parent == :array ? "<#{tag.singularize}>" : ''
    o.each do |k,v|
      k_clean = clean_tag(k) # make sure tag name is valid
      if k.include?('$')
        # don't output tag, this node is meta type info
        out += recurse(v, depth+1, k_clean)
      else
        out += make_tag(k_clean) do
          recurse(v, depth+1, k_clean)
        end
      end
    end
    out += parent == :array ? "</#{tag.singularize}>" : ''
    out
  elsif o.is_a?(Array)
    o.reduce { |_.v| _ + recurse(v, depth+1, tag, :array) }
  else
    # value output
    if ['date', 'created_at'].include? tag
      # attempt to unify dates
      DateTime.parse(o).iso8601
    else
      # encode special characters
      "#{o}".gsub(/\&/, '&amp;')
    end
  end
end

def make_tag(name, attrs=nil)
  attr_str = attrs.reduce('') { |_,(k,v)| _+" #{k}='#{v}'" } if attrs
  "<#{name}#{attr_str}>"+
  yield +
  "</#{name}>"
end

def clean_tag(k)
  k = k[1..-1] if k[0] == '_' || k[0] == '$'
  k.gsub(/\ /, '_').underscore
end

class String
  def pluralize(locale=:en)
    ActiveSupport::Inflector.pluralize(self, locale)
  end

  def singularize(locale=:en)
    ActiveSupport::Inflector.singularize(self, locale)
  end

  def underscore
    ActiveSupport::Inflector.underscore(self)
  end
end

run
