require 'pry'

require "./amesc"

HERE = File.split(__FILE__)[0]

def main(src_root, from, to)
  amesc = Amesc.new(src_root, File.join( HERE, "../pages" ) )
  (from..to).each do |num|
    amesc.get_page(num)
  end
end

main( "https://"+ARGV[0], ARGV[1].to_i, ARGV[2].to_i )
