require 'json'
require 'csv'
require 'time'
require 'pry-byebug'
require 'active_support/inflector'
# require 'nokogiri'

# TODO: re-add <item type="tweet">

def run
  @output_array_scalar_as_node_element = false

  filepath = ARGV[0]
  ext = File.extname(filepath)

  xml = if ext == '.json'
    file = File.new(filepath, "r")
    json = JSON.load(file)
    if json['thread']
      make_tag('root') do
        recurse(json['thread'], 1, 'items')
      end
    elsif json['source'] && ["http://twitter.com", 'reddit'].any? { |s| json['source'].downcase.include? s }
      make_tag('root') do
        recurse([json], 1, 'items')
      end
    else
      make_tag('root') do
        recurse(json)
      end
    end
  elsif ext == '.csv'
    @output_array_scalar_as_node_element = true
    make_tag('root') do
      CSV.read(filepath, headers: true).reduce('') do |output,row|
        # TODO: consider colocating this value extrusion with date/encoding value 
        # output in #recurse
        dict = row.each_with_object({}) do |(header,field), obj|
          next if header.nil?
          if field && field.include?(';')
            # fields containing "Title1: val,val; Title2: val,val;.."
            # become title1: [val, val], title2: [val, val]
            key_values = {}
            field.split(';').each do |kv_pair|
              k,v = kv_pair.split(':')
              key_values[k.pluralize] = v.split(',')
            end
            field = key_values
          elsif field && field.include?(',')
            # comma-separated fields become arrays
            field = field.split(',')
          end
          obj[header] = field
        end
        output + make_tag('item') do
          recurse(dict)
        end
      end
    end
  end
      
  filename = File.basename(filepath, ext)
  File.write("#{filename}.xml", xml)
end

def recurse(o, depth=0, tag=nil, parent=nil)
  if o.is_a?(Hash)
    out = parent == :array ? "<#{clean_tag(tag).singularize}>" : ''
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
    out += parent == :array ? "</#{clean_tag(tag).singularize}>" : ''
    out
  elsif o.is_a?(Array)
    o.reduce('') { |_,v| _ + recurse(v, depth+1, tag, :array) }
  else
    # value output
    out = @output_array_scalar_as_node_element && parent == :array ? "<#{clean_tag(tag).singularize}>" : ''
    out += if ['date', 'created_at'].include? tag
      # attempt to unify dates
      DateTime.parse(o).iso8601
    else
      # encode special characters
      "#{o}".gsub(/\&/, '&amp;').strip
    end
    out += @output_array_scalar_as_node_element && parent == :array ? "</#{clean_tag(tag).singularize}>" : ''
    out
  end
end

def make_tag(name, attrs=nil)
  attr_str = attrs.reduce('') { |_,(k,v)| _+" #{k}='#{v}'" } if attrs
  "<#{name}#{attr_str}>"+
  yield +
  "</#{name}>"
end

def clean_tag(k)
  k = k[1..-1] if k[0] == '_' || k[0] == '$' || k[0] == ' '
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
