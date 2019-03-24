class ShelfController < ApplicationController

  # require 'amazon'
  require 'bookinfo'

  # ファイルの中のパスワードをDBにコピー
  def convert_db
    dir = "/Users/masui/hondana/db/iqauth"
    Dir.open(dir).each { |f|
      if f =~ /^([0-9a-f]+)\.id$/ then
        hash = $1
        id = File.read("#{dir}/#{f}").chomp
        puts "id = #{id}"
        if id =~ /^\d+$/
          puts id
          password = File.read("#{dir}/#{hash}.password").chomp
          query = File.read("#{dir}/#{hash}.query").chomp
          shelf = Shelf.where(id: id)[0]

          origdata = JSON.parse(query)
          data = []
          origdata.each { |entry|
            newentry = {}
            newentry['image'] = entry[0]
            newentry['answers'] = entry[1..100]
            data.push newentry
          }
          quiz = data.to_json

          if shelf then
            shelf.password = password
            shelf.quiz = quiz
            shelf.save
          end
        end
      end
    }
  end
  
  def show # 書籍リストを表示
    shelf = getshelf
    if shelf.nil? then
      redirect_to :controller => 'bookshelf', :action => 'list'
      return
    end

    # e.g. http://hondana.org/増井?page=5&list=image&sort=score
    shelf.listtype = params[:list] || shelf.listtype || 'image'   # image / text / dtail
    shelf.sorttype = params[:sort] || shelf.sorttype || 'recent'  # recent / score
    shelf.save

    render locals: { shelf: shelf, entries: entries(shelf) }
  end

  def edit # 書籍情報編集
    shelf = getshelf
    book = getbook
    entry = getentry(shelf,book)
    
    render locals: { shelf: shelf, book: book, entry: entry }
  end

  def write # 書籍情報書込み
    shelf = getshelf
    book = getbook
    entry = getentry(shelf,book)

    puts "---write---"
    puts "REMOTE_IP = #{request.remote_ip}"
    
    entry.score = params[:entry][:score]
    entry.categories = params[:entry][:categories].sub(/\s*$/,'')
    entry.comment = params[:entry][:comment]
    if entry.comment !~ /a href/ then ### spam
      entry.modtime = Time.now
      entry.clicktime = Time.now
      entry.save
      shelf.modtime = Time.now
      shelf.save
    end
    
    redirect_to :action => 'edit', :shelfname => shelf.name, :isbn => book.isbn
    return
  end

  def newbooks
    shelf = getshelf
    render locals: { shelf: shelf }
  end

  def add
    shelf = getshelf
    s = params[:isbns]
    s.gsub!(/[\r\n]/,' ')
    s.gsub!(/\-/,'')

    isbns = []
    while s =~ /^(.*)(978\d{10})(.*)$/m do
      s = $1+$3
      isbns << id2isbn($2)
    end
    while s =~ /^(.*)(\d{9}[\dX])(.*)$/m do
      s = $1+$3
      isbns << $2
    end

    if isbns.length == 0 then
      redirect_to :action => 'newbooks', :error => "10桁のISBNか13桁のバーコード番号を指定して下さい。"
      return
    end
    if isbns.length >= 10 then
      redirect_to :action => 'newbooks', :error => "ISBN指定は10個までにして下さい。"
      return
    end

    puts "---newbook---"
    puts "REMOTE_IP = #{request.remote_ip}"
    
    isbns.each { |isbn|
      book = Book.where(isbn: isbn)[0]
      if book.nil? then
        bookinfo = Bookinfo.new(isbn)
        book = Book.new
        book.isbn = isbn
        book.title = bookinfo.title
        book.publisher = bookinfo.publisher
        book.authors = bookinfo.authors
        book.price = 0
        book.imageurl = bookinfo.image
        book.modtime = Time.now
        book.save
      end

      entry = Entry.where("book_id = ? and shelf_id = ?", book.id, shelf.id)[0]
      if entry.nil? then
        entry = Entry.new
        entry.book_id = book.id
        entry.shelf_id = shelf.id
        entry.modtime = Time.now
        entry.clicktime = Time.now
        # entry.comment = request.remote_ip.to_s # IP記録
        entry.comment = ""
        entry.score = ''
        entry.categories = ''
        entry.save
      end
    }

    # amazon = MyAmazon.new
    # amazon.get_data(isbns.join(","))
    # isbns.each { |isbn|
    #   book = Book.where(isbn: isbn)[0]
    #   if book.nil? then
    #     book = Book.new
    #     book.isbn = isbn
    #     book.title = amazon.title(isbn)
    #     book.publisher = amazon.publisher(isbn)
    #     book.authors = amazon.authors(isbn)
    #     book.price = 0
    #     book.imageurl = amazon.image(isbn)
    #     book.modtime = Time.now
    #     book.save
    #   end
    #
    #  entry = Entry.where("book_id = ? and shelf_id = ?", book.id, shelf.id)[0]
    #   if entry.nil? then
    #     entry = Entry.new
    #     entry.book_id = book.id
    #     entry.shelf_id = shelf.id
    #     entry.modtime = Time.now
    #     entry.clicktime = Time.now
    #     # entry.comment = request.remote_ip.to_s # IP記録
    #     entry.comment = ""
    #     entry.score = ''
    #     entry.categories = ''
    #     entry.save
    #   end
    #  }

    redirect_to :action => 'edit', :shelfname => shelf.name, :isbn => isbns[0]
  end

  def reload
    shelf = getshelf
    params[:isbn] =~ /\d{9}[\dX]/
    isbn = $&
    book = Book.where(isbn: isbn)[0]
    if book.nil? then
      book = Book.new
      book.isbn = isbn
    end

    bookinfo = Bookinfo.new(isbn)
    book = Book.new
    book.isbn = isbn
    book.title = bookinfo.title
    book.publisher = bookinfo.publisher
    book.authors = bookinfo.authors
    book.price = 0
    book.imageurl = bookinfo.image
    book.modtime = Time.now
    book.save
    
    #amazon = MyAmazon.new
    #book.title = amazon.title(isbn)
    #book.publisher = amazon.publisher(isbn)
    #book.authors = amazon.authors(isbn)
    #book.price = 0
    #book.imageurl = amazon.image(isbn)
    #book.modtime = Time.now
    #book.save
  end

  def profile_edit
    shelf = getshelf
    render locals: { shelf: shelf }
  end

  def profile_write
    shelf = getshelf

    puts "---profile_write---"
    puts "AUTH_TOKEN = #{params[:authenticity_token]}"
    puts "VERIFIED = #{verified_request?}"
    
    # if cookies[:CurrentShelf] == @shelf.name then
    description = params[:shelf][:description]
    affiliateid = params[:shelf][:affiliateid]
    url = params[:shelf][:url]
    
    shelf.description = description
    shelf.url = url
    shelf.affiliateid = affiliateid
    shelf.use_iqauth = (params[:shelf][:use_iqauth].to_s == '1' ? '1' : '0')

    challenge = params[:challenge]
    response = params[:response]
    
    #    require "digest/md5"
    #    if Digest::MD5.hexdigest(response) != ansmd5 then
    #      redirect_to :action => 'profile_edit'
    #      return
    #    end
    #    #
    #    # 常識サーバからは、問題を暗号化したものも返る
    #    # これを公開鍵で復号できればOK
    #    #
    #    public_key = nil
    #    File.open(Rails.root.join("config","id_rsa_pub").to_s) do |f|
    #      public_key = OpenSSL::PKey::RSA.new(f)
    #    end
    #    qq = ""
    #    t = 0
    #    begin
    #      ss = Base64.decode64(enctime)
    #      ss = public_key.public_decrypt(ss, mode = OpenSSL::PKey::RSA::PKCS1_PADDING).force_encoding('utf-8')
  #      (qq, t) = ss.split(/\t/)
    #    rescue
    #    end
    #    if qq != challenge || Time.now - Time.at(t.to_i) > 30
    #      redirect_to :action => 'profile_edit'
    #      return
    #    end

    unless check_joushiki(challenge,response)
      redirect_to :action => 'profile_edit'
      return
    end
    #    #
    #    # 常識サーバからは、問題を暗号化したものも返る
    #    # これを公開鍵で復号できればOK
    #    #
    #    public_key = nil
    #    File.open(Rails.root.join("config","id_rsa_pub").to_s) do |f|
    #      public_key = OpenSSL::PKey::RSA.new(f)
    #    end
    #    qq = ""
    #    t = 0
    #    begin
    #      ss = Base64.decode64(enc)
    #      ss = public_key.public_decrypt(ss, mode = OpenSSL::PKey::RSA::PKCS1_PADDING).force_encoding('utf-8')
    #      (qq, t) = ss.split(/\t/)
    #    rescue
    #    end
    #    if qq != challenge[0..10] || Time.now - Time.at(t.to_i) > 30
    #      redirect_to :action => 'profile_edit'
    #      return
    #    end
    
    shelf.save # 編集を許さないときはコメントアウト

    #if description !~ /href=/i then
    #  # 単純なタグだけ許す細工
    #  desc = description.gsub(/<(\/?(b|br|p|ul|ol|li|dl|dt|dd|hr|pre|blockquote|del))>/i,'')
    #  if desc !~ /</ && description !~ /%3c/i then
    #    if affiliateid !~ /</ && affiliateid !~ /%3c/i then
    #      if url !~ /</ && url !~ /%3c/i then
    #        @shelf.description = description
    #        @shelf.url = url
    #        @shelf.affiliateid = affiliateid
    #        @shelf.use_iqauth = params[:shelf][:use_iqauth]
    #        @shelf.save
    #      end
    #    end
    #  end
    #end
    # end
    redirect_to :action => 'profile_edit'
  end

  def help
    shelf = getshelf
    render locals: { shelf: shelf }
  end

  def rename
    shelf = getshelf
    render locals: { shelf: shelf }
  end

  def delete
    shelf = getshelf
    book = getbook
    entry = getentry(shelf,book)
    render locals: { shelf: shelf, book: book, entry: entry }
  end

  def realdelete
    shelf = getshelf
    book = getbook
    entry = getentry(shelf,book)
    entry.destroy
    redirect_to :shelfname => shelf.name, :action => 'show'
  end

  def datalist
    shelf = getshelf

    jsonstr = shelf.entries.collect { |entry|
      book = entry.book
      {
        title:      book.title,
        isbn:       book.isbn,
        date:       entry.modtime,
        publisher:  book.publisher,
        authors:    book.authors,
        categories: entry.categories,
        score:      entry.score,
        comment:    entry.comment
      }
    }.to_json
        .gsub(/","/,"\",\n  \"")
        .gsub(/\},\{/,"\n},\n{")
        .gsub(/\{"/,"{\n  \"")
        .gsub(/":"/,"\" : \"")
        .sub(/\[\{/,"[\n{")
        .sub(/\}\]/,"\n}\n]")
        .gsub(/</,"&lt;")

    render locals: { shelf: shelf, jsonstr: jsonstr }
  end
  
  def category_detail
    shelf = getshelf
    render locals: { shelf: shelf, category: params[:category]  }
  end
  
  def category_simple
    shelf = getshelf
    render locals: { shelf: shelf, category: params[:category]  }
  end
  
  def category_bookselect
    shelf = getshelf
    render locals: { shelf: shelf, category: params[:category]  }
  end

  def category_bookset
    shelf = getshelf
    category = params[:category]
    isbns = Set.new
    params.each { |key,val|
      if key =~ /^\d{9}[\dX]$/ then
        isbns.add(key)
      end
    }
    shelf.entries.each { |entry|
      categories = Set.new(entry.categories.split(/,\s*/))
      if categories.member?(category) && !isbns.member?(entry.book.isbn) then
        categories.delete(category)
      elsif !categories.member?(category) && isbns.member?(entry.book.isbn) then
        categories.add(category)
      end
      entry.categories = categories.to_a.join(', ')
      entry.save
    }
    redirect_to :action => 'category_bookselect', :category => category
  end
  
  def category_rename
    shelf = getshelf
    render locals: { shelf: shelf, category: params[:category]  }
  end
  
  def category_setname
    shelf = getshelf
    category = params[:category]
    newcategory = params[:newcategory]
    shelf.entries.each { |entry|
      categories = Set.new(entry.categories.split(/,\s*/))
      if categories.member?(category) then
        categories.delete(category)
        categories.add(newcategory) if newcategory != ''
        entry.categories = categories.to_a.join(', ')
        entry.save
      end
    }
    redirect_to :action => (newcategory == '' ? 'category_text' : 'category_detail'), :category => newcategory
  end
  
  def setname
    shelf = getshelf
    newname = params[:shelf][:name]
    challenge = params[:challenge]
    response = params[:response]
    enc = params[:enc]

    puts "AUTH_TOKEN = #{params[:authenticity_token]}"
    puts "VERIFIED = #{verified_request?}"
    puts "shelf = #{shelf.name}"
    puts "challenge = #{challenge}"
    puts "response = #{response}"
    if !verified_request? # これは必要??
      redirect_to :action => 'show', :shelfname => shelf.name
      return
    end

    # # spam対策のため、!! を最後につけたときだけ名前変更を許す
    # puts "newname = #{newname}"
    # if newname !~ /!!$/ then
    #   redirect_to :action => 'show', :shelfname => shelf.name
    #   return
    # end
    # newname.sub!(/!!$/,'')

    #    #
    #    # 回答が正しいかチェック
    #    #
    #    if Digest::MD5.hexdigest(response) != ansmd5 then
    #      redirect_to :action => 'show', :shelfname => shelf.name
    #      return
    #    end
    #    #
    #    # 常識サーバからは、問題を暗号化したものも返る
    #    # これを公開鍵で復号できればOK
    #    #
    #    public_key = nil
    #    File.open(Rails.root.join("config","id_rsa_pub").to_s) do |f|
    #      public_key = OpenSSL::PKey::RSA.new(f)
    #    end
    #    ss = " \t0"
    #    begin
    #      ss = Base64.decode64(enctime)
  #    ss = public_key.public_decrypt(ss, mode = OpenSSL::PKey::RSA::PKCS1_PADDING).force_encoding('utf-8')
    #    rescue
    #    end
    #    (qq, t) = ss.split(/\t/)
    #    if qq != challenge || Time.now - Time.at(t.to_i) > 30
    #      redirect_to :action => 'show', :shelfname => shelf.name
    #      return
    #    end

    puts "challenge=#{challenge}, response=#{response}"

    unless check_joushiki(challenge,response)
      redirect_to :action => 'show', :shelfname => shelf.name
      return
    end
    
    #    #
    #    # 常識サーバからは、問題を暗号化したものも返る
    #    # これを公開鍵で復号できればOK
    #    #
    #    public_key = nil
    #    File.open(Rails.root.join("config","id_rsa_pub").to_s) do |f|
    #      public_key = OpenSSL::PKey::RSA.new(f)
    #    end
    #    qq = ""
    #    t = 0
    #    begin
    #      ss = Base64.decode64(enc)
    #      ss = public_key.public_decrypt(ss, mode = OpenSSL::PKey::RSA::PKCS1_PADDING).force_encoding('utf-8')
    #      (qq, t) = ss.split(/\t/)
    #    rescue
    #    end
    #    if qq != challenge[0...10] || Time.now - Time.at(t.to_i) > 30
    #      redirect_to :action => 'show', :shelfname => shelf.name
    #      return
    #    end
    
    if newname.index('<') || newname =~ /%3c/i then # 変な名前を許さない
      redirect_to :action => 'show', :shelfname => shelf.name
      return
    end

    # return # SPAM対策するときはここでリターンしてしまう

    puts "newname = #{newname}"
    if newname == '' then
      newname = shelf.name + '_deleted000'
      while Shelf.where(:name => newname).length > 0
        newname = newname.succ
      end
      puts "newname = #{newname}"
      # redirect_to :controller => 'bookshelf', :action => 'list'
      # return
    else
      if Shelf.where(:name => newname).length > 0 then
        redirect_to :action => 'rename', :shelfname => newname, :error => "同じ名前の本棚が存在します"
        return
      end
    end

    shelf.name = newname # 本棚名変更!!
    shelf.modtime = Time.now
    # shelf.save # 変更した名前をセーブ

    if newname =~ /_deleted/ then
      redirect_to :controller => 'bookshelf', :action => 'list'
    else
      redirect_to :action => 'show', :shelfname => newname
    end

#    if newname == '' then
#      # 本棚消去する必要があるが、どうやるかは未定。
#      newname = 
#    end
#    if Shelf.find(:first, :conditions => ["name = ?", newname]).nil? then
#      @shelf.name = newname # 本棚名変更!!
#      @shelf.modtime = Time.now
#      @shelf.save
#    else
#      # 本棚が既に存在する.... エラーをうまく表示すること。
#      # @shelf.errors.add_to_base("同じ名前の本棚が存在します") だとうまくいかない...
#      @newname = @shelf.name
#      redirect_to :action => 'rename', :shelfname => @newname, :error => "同じ名前の本棚が存在します"
#    end
#    redirect_to :action => 'show', :shelfname => @newname
  end
  
  def category
    shelf = getshelf
    # logger.debug "Category: shelf=#{shelf}"
    shelf.listtype = params[:list]

    categories = Set.new
    shelf.entries.each { |entry|
      entry.categories.split(/,\s*/).each { |category|
        categories.add category if category != ''
      }
    }
    render locals: { shelf: shelf, categories: categories.to_a.sort }
  end

  def editquiz
    shelf = getshelf
    
    render locals: { shelf: shelf }
  end

  def registerquiz
    shelf = getshelf

    shelf.quiz = params[:quiz]
    shelf.password = params[:pass]
    shelf.save
    
    redirect_to :action => 'profile_edit'
    return
  end

  private
  
  def entries(shelf)
    per_page = (shelf.listtype == 'image' ? 60 : shelf.listtype == 'text' ? 200 : 20)
    sort = (shelf.sorttype == 'recent' ? "modtime DESC" : "score DESC")
    Entry.where(shelf_id: shelf.id).order(sort).paginate(:page => params[:page], :per_page => per_page)
  end
  
  def getshelf
    shelfname = params[:shelfname]
    Shelf.where(name: shelfname)[0]
  end

  def getbook
    params[:isbn] =~ /\d{9}[\dX]/
    isbn = $&
    Book.where(isbn: isbn)[0]
  end

  def getentry(shelf, book)
    p shelf
    p book
    Entry.where("shelf_id = ? and book_id = ?", shelf.id, book.id)[0]
  end

  def add_checksum(isbn)
    v = 0
    (0..8).each { |i|
      v += isbn[i,1].to_i * (i+1)
    }
    v %= 11
    checksum = (v == 10 ? 'X' : v.to_s)
    isbn + checksum
  end

  def id2isbn(id)
    # 書籍のバーコードのISBNは'978'で始まり、チェックサムで終わっている
    # ようなのでこれを除去してISBNのチェックサムを付加する
    #
    add_checksum(id.gsub(/^.../,'').gsub(/.$/,''))
  end

end
