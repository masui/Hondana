# -*- coding: utf-8 -*-
# -*- ruby -*-
#
# 書籍データを取得 (Amazon以外の方法で)
#

require 'net/http'
require 'open-uri'
require 'open_bd'
require 'json'

class Bookinfo
  def emptydata
    data = {}
    data['authors'] = []
    data['title'] = ''
    data['publisher'] = ''
    data['isbn'] = @isbn
    data
  end
  
  def initialize(isbn)
    @isbn = isbn
    @data = emptydata

    @data = amazon
    data = openbd
    @data['title'] = data['title'] if @data['title'] == ''
    @data['publisher'] = data['publisher'] if @data['publisher'] == ''
    @data['authors'] = data['authors'] if @data['authors'].length == 0
    data = google
    @data['title'] = data['title'] if @data['title'] == ''
    @data['publisher'] = data['publisher'] if @data['publisher'] == ''
    @data['authors'] = data['authors'] if @data['authors'] == []
  end
  
  def amazon
    data = emptydata
    begin
      url = "https://www.amazon.co.jp/dp/#{@isbn}"
      page = open(url)
      html = page.read
      html.split(/\n/).each { |line|
        case
        when line =~ /<title>/
          line =~ /<title>([^\|]+)\s+\|\s*([^\|]+)\s*.*<\/title>/
          data['title'] = $1
          data['authors'] = $2.split(/,\s*/)
        #when line =~ /field-author/
        #  line =~ />(.*)<\/a>/
        #  data['authors'] << $1
        when line =~ /isbn-10/i
          line =~ /\/b>\s*(.*)<\/li>/
          data['isbn'] = $1
        #when line =~ /出版社/
        when line =~ /出版社.*\/b>\s*([^\(]+)(\s*;.*)\s*(\(.*\))?<\/li>/
          data['publisher'] = $1
        when line =~ /出版社.*\/b>\s*([^\(]+)\s*(\(.*\))?<\/li>/
          # <li><b>出版社:</b> SBクリエイティブ (2019/3/16)</li>
          # <li><b>出版社:</b> 講談社 (2008/5/13)</li>
          data['publisher'] = $1
        end
      }
    rescue
    end
    data
  end

  def openbd
    data = emptydata
    begin
      client = OpenBD::Client.new
      res = client.search(isbns: [@isbn])
      res.body[0]['summary']['author'].split(/\s+/).each { |s|
        author = ''
        if s =~ /^(.*)／著/
          author = $1
        end
        if s =~ /^(.*)／翻訳/
          author = $1
        end
        author.gsub!(/,/, ', ')
        author.gsub!(/([a-z])([A-Z])/,"\\1 \\2")
        data['authors'] << author if author != ''
      }
      data['title'] = res.body[0]['summary']['title']
      data['publisher'] = res.body[0]['summary']['publisher']
    rescue
    end
    data
  end
  
  def google
    data = emptydata
    begin
      uri = URI.parse("https://www.googleapis.com/books/v1/volumes?q=isbn:#{@isbn}")
      data = JSON.parse uri.read
      volumeinfo = data['items'][0]['volumeInfo']
      data['publisher'] = ''
      data['title'] = volumeinfo['title']
      data['authors'] = volumeinfo['authors']
    rescue
    end
    data
  end
  
  def image
    cands = [
      ["images-jp.amazon.com", "/images/P/#{@isbn}.01._OU09_PE0_SCMZZZZZZZ_.jpg"], # 2006/3/6 tsuika
      ["images-jp.amazon.com", "/images/P/#{@isbn}.09.MZZZZZZZ.jpg"],
      ["images-jp.amazon.com", "/images/P/#{@isbn}.01.MZZZZZZZ.jpg"],
      ["bookweb.kinokuniya.co.jp","/imgdata/#{@isbn}.jpg"],
    ]
    imageurl(cands)
  end

  def imageurl(cands)
    ret = ""
    cands.each { |c|
      host = c[0]
      path = c[1]
      url = "http://#{host}#{path}"
      response = ''
      Net::HTTP.start(host, 80) { |http|
        response = http.get(path)
      }
      if response.class == Net::HTTPOK && response.body.length > 1000 then
        ret = url
        break
      end
    }
    ret
  end

  def title
    @data['title']
  end
  
  def publisher
    @data['publisher']
  end
  
  def authors
    @data['authors'].join(', ')
  end
end

if __FILE__ == $0 then
  isbn = '4065020352'
  isbn = '4797399287'
  isbn = '4320026926'
  isbn = '4063192393'
  isbn = '0262011530'
  isbn = '4065145139'
  isbn = '4297104636'
  isbn = '430902744X'
  bookinfo = Bookinfo.new(isbn)
  puts bookinfo.title
  puts bookinfo.publisher
  puts bookinfo.authors.join(', ')
  puts bookinfo.image
end
