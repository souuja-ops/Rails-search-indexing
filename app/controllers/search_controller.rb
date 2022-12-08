class SearchController < ApplicationController
  def index
  end

  def search
    term = params[:term].strip
    @articles = Article.where("lower(title) LIKE ?", "%#{term.downcase}%")

    redis = Redis.new(url: ENV["REDIS_URL"])
    time = DateTime.now.strftime("%Q")
    ip = request.ip
    redis.set(
      "ip:#{ip}:#{time}",
      {
        term: term,
        submit: params[:submit],
        ip: ip,
        sought_at: time,
        article_count: @articles.count,
      }.to_json
    )
    redis.close

    respond_to do |format|
      format.json { render json: @articles, :only => [:id, :title] }
    end
  end

  def statistics
    @searches = Search.order(count: :desc)
    respond_to do |format|
      format.json { render json: @searches, :only => [:id, :term, :count, :article_count, :zero_article_count] }
      format.html
    end
  end

  def clear_statistics
    Search.destroy_all
    redirect_to search_statistics_url, notice: "All statistics were deleted."
  end
end
