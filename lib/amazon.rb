# -*- coding: utf-8 -*-
# -*- ruby -*-
#
# Amazonの書籍データを取得
#

require "amazon/ecs"

class MyAmazon
  @@data = {}
  ASSOC_ID = 'pitecancom-22'
  
  def get_data(isbns) # "4837976425,4761261773", etc.
    #
    # 書籍データ取得
    # 10個まで取得可能
    # 連続呼び出しできない
    #
    # 認証情報は環境変数に書いておく
    #
    begin
      Amazon::Ecs.configure do |options|
        options[:AWS_access_key_id] = ENV["AWS_ACCESS_KEY_ID"]
        options[:AWS_secret_key]    = ENV["AWS_SECRET_ACCESS_KEY"]
        options[:associate_tag]     = ASSOC_ID
        options[:country]           = 'jp'
      end

      sleep 2
      res = Amazon::Ecs.item_lookup isbns
      p res
      exit
      
      res.items.each do |item|
        isbn =item.get('ASIN')
        element = item.get_element('ItemAttributes');
        @@data[isbn] = {}
        @@data[isbn]['Title'] = element.get('Title').to_s
        @@data[isbn]['Author'] = element.get('Author').to_s
        @@data[isbn]['Publisher'] = element.get('Manufacturer').to_s
      end
    rescue => e
      if __FILE__ == $0 then
        puts "Amazon API error... isbn=#{isbns}"
        puts e
      else
        # logger.debug "Amazon API error... isbn=#{isbns}"
      end
    end
  end

  def get_onedata(isbn)
    unless @@data[isbn]
      get_data isbn
    end
  end

  def publisher(isbn)
    get_data(isbn)
    if @@data[isbn].nil? then
      get_data(isbn)
    end
    @@data[isbn]['Publisher']
  end

  def authors(isbn)
    get_data(isbn)
    if @@data[isbn].nil? then
      get_data(isbn)
    end
    @@data[isbn]['Author']
  end

  def title(isbn)
    get_data(isbn)
    if @@data[isbn].nil? then
      get_data(isbn)
    end
    @@data[isbn]['Title']
  end

  def image(isbn)
    cands = [
      ["images-jp.amazon.com", "/images/P/#{isbn}.01._OU09_PE0_SCMZZZZZZZ_.jpg"], # 2006/3/6 tsuika
      ["images-jp.amazon.com", "/images/P/#{isbn}.09.MZZZZZZZ.jpg"],
      ["images-jp.amazon.com", "/images/P/#{isbn}.01.MZZZZZZZ.jpg"],
      ["bookweb.kinokuniya.co.jp","/imgdata/#{isbn}.jpg"],
    ]
    imageurl(isbn,cands)
  end

  def imageurl(isbn,cands)
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

  def url(isbn)
    "http://www.amazon.co.jp/exec/obidos/ASIN/#{isbn}/#{ASSOC_ID}/ref=nosim/"
  end
end

if __FILE__ == $0 then
  amazon = MyAmazon.new
  isbn = '0262011530'
  isbn = '4063192393'
  isbn = '4065020352'
  puts amazon.title(isbn)


  exit
  puts amazon.publisher(isbn)
  puts amazon.authors(isbn)
  puts amazon.url(isbn)
  puts amazon.image(isbn)
end
