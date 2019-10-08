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
    sc['src'] = nil
  end
end

class Amesc
  def initialize(src_root, dest)
    @dest = dest
    @src_root = src_root
  end
  attr_reader(:dest, :src_root)

  def download(uri, dest)
    return if File.exist?(dest)

    puts("download: #{uri}")
    body = OpenURI.open_uri(uri.to_s, &:read)
    sleep(1)
    FileUtils.mkdir_p(File.split(dest)[0])
    File.open(dest, 'w') { |f| f.write(body) }
  end

  def local_path(uri, dir)
    ext = File.extname(uri.path).downcase
    body = Digest::SHA256.hexdigest(uri.to_s)
    File.join(dest, dir, "#{body}#{ext}")
  end

  def get_file(uri, dir, scheme, host)
    uri.scheme ||= scheme
    uri.host ||= host
    uri.query = nil
    path = local_path(uri, dir)
    download(uri, path)
    path
  end

  def get_image(uri, scheme, host)
    get_file(uri, 'img', scheme, host)
  end

  def get_css(uri, scheme, host)
    get_file(uri, 'css', scheme, host)
  end

  def image?(uri)
    ext = File.extname(uri.path).downcase
    %w[.jpg .gif .png .jpeg].include?(ext)
  end

  def get_images(doc, scheme, host)
    doc.xpath('//img').each do |img|
      src = img['src']
      next unless src
      img_uri = URI.parse(src)
      next unless image?(img_uri)

      img_path = get_image(img_uri, scheme, host)
      img['src'] = File.relative_path(dest, img_path)
    end
  end

  def download_rel?(rel)
    %w[stylesheet].include?(rel)
  end

  def get_css_images(uri, path)
    mod = lambda do |all, ustr|
      u = URI.parse(ustr)
      if u.absolute? && image?(u)
        e_path = get_image(u, uri.scheme, uri.host)
        %!url("#{File.relative_path(path, e_path)}")!
      else
        all
      end
    end
    s = File.open(path, &:read)
    s.gsub!(/url\s*\(\s*\"([^\"]+)\"\s*\)/) do |all|
      mod[all, Regexp.last_match(1)]
    end
    s.gsub!(/url\s*\(\s*\'([^\']+)\'\s*\)/) do |all|
      mod[all, Regexp.last_match(1)]
    end
    File.open(path, "w") do |f|
      f.write(s)
    end
  end

  def get_links(doc, scheme, host)
    doc.xpath('//link').each do |link|
      next unless download_rel?(link['rel'])

      uri = URI.parse(link['href'])
      path = get_css(uri, scheme, host)
      link['href'] = File.relative_path(dest, path)
      get_css_images(uri, path)
    end
  end

  def get_page(num)
    html_uri = "#{src_root}/page-#{num}.html"
    scheme, host = URI.parse(html_uri).then { |x| [x.scheme, x.host] }
    doc = setup_doc(html_uri)
    get_links(doc, scheme, host)
    get_images(doc, scheme, host)
    remove_scripts(doc)
    html_fn = File.join(File.join(dest, "#{num}.html"))
    File.open(html_fn, 'w') { |f| f.puts(doc.to_html) }
  end
end
