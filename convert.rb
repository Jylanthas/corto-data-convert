#!/usr/bin/env ruby
require 'json'
require 'csv'
require 'nokogiri'
require 'time'
require 'pry-byebug'
require 'active_support/inflector'

# TODO: re-add <item type="tweet">

def run
  filepath = ARGV[0]
  outpath = ARGV[1]
  validate = ARGV[2] && ARGV[2] == 'true'

  if File.directory?(filepath)
    paths = Dir[File.join(filepath, '/**/*.{json,csv}')]
    puts "#{paths.length} files"
    paths.each_with_index do |path,i|
      perc = 100 * (i.to_f / paths.length)
      progress = "=" * (perc/5) unless perc < 5
      printf("\r: [%-20s] %.2f%% %s", progress, perc, spinner.next)

      # default: write sibling file to base dir of filepath
      # outpath dir given: write outpath dir + path remaining after filepath base dir
      outfile = if outpath.nil?
          File.dirname(path)
        else
          File.join(outpath, path[filepath.length..-1]).tap do |p|
            FileUtils.mkdir_p(File.dirname(p))
          end
        end
      convert(path, outfile, validate)
    end
  else
    # outfile = if outpath.nil?
    #     File.dirname(filepath)
    #   else
    #     binding.pry
    #     File.join(outpath, outpath[filepath.length..-1]).tap do |p|
    #       FileUtils.mkdir_p(File.dirname(p))
    #     end
    #   end
    convert(filepath, outpath, validate)
  end
end

def convert(filepath, outpath=nil, validate=false)
  @output_array_scalar_as_node_element = false
  ext = File.extname(filepath)

  xml = if ext == '.json'
    file = File.new(filepath, "r")
    json = JSON.load(file)
    if json['thread']
      make_element('root') do
        recurse(json['thread'], 1, 'items')
      end
    elsif json['source'] && ["http://twitter.com", 'reddit'].any? { |s| json['source'].downcase.include? s }
      make_element('root') do
        recurse([json], 1, 'items')
      end
    else
      make_element('root') do
        recurse(json)
      end
    end
  elsif ext == '.csv'
    @output_array_scalar_as_node_element = true
    make_element('root') do
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
              key_values[k.pluralize] = v && v.split(',')
            end
            field = key_values
          elsif field && field.include?(',')
            # comma-separated fields become arrays
            field = field.split(',')
          end
          obj[header] = field
        end
        output + make_element('item') do
          recurse(dict)
        end
      end
    end
  end
      
  outpath = if outpath.nil?
    File.basename(filepath, ext) + '.xml' # current dir
  else
    if File.directory?(outpath) # directory (outpath) + filename.xml
      File.join(outpath, File.basename(filepath, ext) + '.xml')
    else # directory (file) + filename.xml
      File.join(File.dirname(outpath), File.basename(filepath, ext) + '.xml')
    end
  end
  File.write(outpath, xml)
  
  if validate
    errors = Nokogiri::XML(xml).errors
    unless errors.empty?
      puts filepath
      puts outpath
      puts errors
    end
  end
end

def recurse(o, depth=0, parent_element=nil, parent_type=nil)
  if o.is_a?(Hash)
    out = o.reduce('') do |mem, (k,v)|
      k_clean = clean_name(k) # make sure tag name is valid
      if k.include?('$')
        # don't output tag, this node is meta type info
        mem + recurse(v, depth+1, k_clean)
      else
        mem + make_element(k_clean) do
          recurse(v, depth+1, k_clean)
        end
      end
    end
    
    if parent_type == :array
      make_element(clean_name(parent_element).singularize) do # creates child element <things><thing></thing></things>
        out
      end
    else
      out
    end
  elsif o.is_a?(Array)
    o.reduce('') { |_,v| _ + recurse(v, depth+1, parent_element, :array) }
  else
    # value output
    text = if ['date', 'created_at'].any? { |k| parent_element.include?(k) }
      # attempt to unify dates, if parse fails, leave it be
      DateTime.parse(o).iso8601 rescue clean_text(o)
    else
      clean_text(o)
    end

    if @output_array_scalar_as_node_element && parent_type == :array
      make_element(clean_name(parent_element).singularize) do
        text
      end
    else
      text
    end
  end
end

def make_element(name, attrs=nil)
  attr_str = attrs.reduce('') { |_,(k,v)| _+" #{k}='#{v}'" } if attrs
  "<#{name}#{attr_str}>"+
  yield +
  "</#{name}>"
end

def clean_name(name)
  name = name.gsub(/[ ,-]/, '_')
  name = name.gsub(/#/, 'num')
  name = name.gsub(/%/, 'pct')
  name = name.gsub(/[^a-zA-Z0-9_]/, '')
  name = name[1..-1] if name[0] == '_'
  name = name.gsub(/(^[0-9]+$)/, 'el\1') # numerical elements { "25" => val } becomes <el25></el25>
  name
end

def clean_text(text)
  text = "#{text}".gsub("\u001A", '').strip # remove special characters
  if text.include?('<') && text.include?('>') # seems to include xml (or html). comment out, don't embed as-is
    "<!--#{text}-->"
  else
    # "#{o}".encode(xml: :text).gsub("\u001A", '').strip
    text.encode(xml: :text)
  end
end

def spinner
  @spinner ||= Enumerator.new do |e|
    loop do
      e.yield '|'
      e.yield '/'
      e.yield '-'
      e.yield '\\'
    end
  end
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
