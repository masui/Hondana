class BookshelfController < ApplicationController
  def search
    query = params[:query]
    if query =~ /^\s*$/ then
      redirect_to :action => 'list'
      return
    else
      # 100件に限る
      books = Book.where("authors like ? or title like ?", "%#{query}%", "%#{query}%").limit(100)
      # コメントの中も検索したいかも
    end
    render locals: { query: query, books: books }
  end

  def list
    newentries = Entry.limit(10).where.not(:comment => "").order("modtime DESC") # _deletedな本棚の本も見えてしまう? まぁ良いか??
    dispshelves = Shelf.limit(15).order("modtime DESC").where.not("name like '%_deleted%'")
    rand = Shelf.order("random()").limit(10) # .where.not("name like '%_deleted%'")

    render locals: { newentries: newentries, dispshelves: dispshelves, rand: rand }
  end
  
  def shelfsearch
    query = params[:query]
    newentries = Entry.limit(10).where.not(:comment => "").order("modtime DESC") # _deletedな本棚の本も見えてしまう? まぁ良いか??
    dispshelves = Shelf.limit(15).where("name like '%#{query}%'").where.not("name like '%_deleted%'").order("modtime DESC")
    rand = Shelf.order("random()").limit(10).where.not("name like '%_deleted%'")

    render :action => 'list', locals: { newentries: newentries, dispshelves: dispshelves, rand: rand }
  end

  def randombook
    entry = Entry.order("random()").limit(1)[0]
    redirect_to :controller => 'shelf', :action => 'edit', :shelfname => entry.shelf.name, :isbn => entry.book.isbn
  end
  
  def create
    puts "Create"
    puts "verified = #{verified_request?}" # CSRFでここまで来てないのかな?
    
    # redirect_to :action => 'list' # 本棚作成を許さない場合
    if !verified_request? # これは必要??
      redirect_to :controller => 'bookshelf', :action => 'list'
      return
    end

    shelfname = params[:shelfname]
    challenge = params[:challenge]
    response = params[:response]

    puts "shelf = #{shelfname}"
    puts "challenge = #{challenge}"
    puts "response = #{response}"
    #    #
    #    # 回答が正しいかチェック
    #    #
    #    if Digest::MD5.hexdigest(response) != ansmd5 then
    #      redirect_to :action => 'list'
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
    #      ss = public_key.public_decrypt(ss, mode = OpenSSL::PKey::RSA::PKCS1_PADDING).force_encoding('utf-8')
    #    rescue
    #    end
    #    (qq, t) = ss.split(/\t/)
    #    if qq != challenge || Time.now - Time.at(t.to_i) > 30
    #      redirect_to :action => 'list'
    #      return
    #    end

    puts "challenge=#{challenge}, response=#{response}"

    # unless check_joushiki(challenge,response)
    #   redirect_to :action => 'list'
    #   return
    # end

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
    #      redirect_to :action => 'list'
    #      return
    #    end

    shelf = Shelf.where(name: shelfname)[0]
    if shelf.nil? then
      shelf = Shelf.new
      shelf.name = shelfname
      shelf.description = ''
      shelf.url = ''
      shelf.affiliateid = ''
      shelf.theme = ''
      shelf.themeurl = ''
      shelf.listtype = 'image'
      shelf.sorttype = 'recent'
      shelf.modtime = Time.now
      shelf.save
    end
    redirect_to :controller => 'shelf', :action => 'show', :shelfname => shelfname
  end

  def atom
    # 意味わからないが、こういうの用意すると views/bookshelf/atom.xml.erb が使える
    respond_to do |format|
      format.xml
    end
  end
end

