# frozen_string_literal: true

require 'nokogiri'
require 'open-uri'
require 'fileutils'
require 'yard' # to use File.relative_path
require 'digest/sha2'

def setup_doc(url)
  charset = 'utf-8'
  html = OpenURI.open_uri(url, &:read)
  sleep(1)
  Nokogiri::HTML.parse(html, nil, charset)
end

def remove_scripts(doc)
  doc.xpath('//script').each do |sc|
    sc.children.unlink
  end
end

class Amesc
  def initialize(src_root, dest)
    @dest = dest
    @src_root = src_root
    @downloaded = {}
  end
  attr_reader(:dest, :src_root)

  def download(uri, dest)
    return if @downloaded[uri.to_s]

    puts("download: #{uri}")
    body = OpenURI.open_uri(uri.to_s, &:read)
    sleep(1)
    FileUtils.mkdir_p(File.split(dest)[0])
    File.open(dest, 'w') { |f| f.write(body) }
    @downloaded[uri.to_s] = true
  end

  def local_img_path(uri, ext)
    body = Digest::SHA256.hexdigest(uri.to_s)
    File.join(dest, 'img', "#{body}#{ext}")
  end

  def get_page(num)
    html_uri = "#{src_root}/page-#{num}.html"
    scheme, host = URI.parse(html_uri).then { |x| [x.scheme, x.host] }
    doc = setup_doc(html_uri)
    doc.xpath('//img').each do |img|
      src = img['src']
      img_uri = URI.parse(src)
      ext = File.extname(img_uri.path).downcase
      next unless %w[.jpg .gif .png .jpeg].include?(ext)

      img_uri.scheme ||= scheme
      img_uri.host ||= host
      img_uri.query = nil
      img_path = local_img_path(img_uri, ext)
      download(img_uri, img_path)
      img['src'] = File.relative_path(dest, img_path)
    end
    remove_scripts(doc)
    html_fn = File.join(File.join(dest, "#{num}.html"))
    File.open(html_fn, 'w') { |f| f.puts(doc.to_html) }
  end
end
