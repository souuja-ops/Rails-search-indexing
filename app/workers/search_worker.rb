class SearchWorker
  include Sidekiq::Worker

  def perform
    redis = get_redis_instance

    redis = Redis.new(url: ENV["REDIS_URL"])
    keys = redis.scan_each(match: "ip:*").to_a.sort
    if keys.none?
      redis.close
      return
    end
    searches = organize(keys)

    searches.each do |ip, searches|
      if searches.one?
        save_search searches.first["term"], searches.first["article_count"]
        next
      end
      searches[0..-2].each_with_index do |s, i|
        next_s = searches[i + 1]
        submit = s["submit"] == "true"
        if submit
          save_search s["term"], s["article_count"]
          next
        end
        diff = next_s["sought_at"].to_i - s["sought_at"].to_i
        if diff > 3000
          save_search s["term"], s["article_count"]
          next
        end
      end
      next_s = searches.last
      diff = next_s["sought_at"].to_i - searches[-2]["sought_at"].to_i
      submit = next_s["submit"] == "true"
      save_search next_s["term"], next_s["article_count"] #if submit || diff > 3000
    end

    redis.del keys
    redis.close
  end

  private

  def get_redis_instance
    @redis = Redis.new(url: ENV["REDIS_URL"]) unless @redis
    @redis
  end

  def organize(keys)
    redis = get_redis_instance
    searches = {}
    keys.each do |k|
      ip = k.split(":")[1]
      searches[ip] = [] unless searches[ip]
      searches[ip] << JSON.parse(redis.get(k))
    end
    searches
  end

  def save_search(term, article_count)
    search = Search.find_by_term(term)
    if search
      search.count += 1
      search.article_count += article_count
      search.zero_article_count += 1 if article_count == 0
      search.save
    else
      search = Search.create(
        term: term,
        count: 1,
        article_count: article_count,
        zero_article_count: (article_count == 0 ? 1 : 0),
      )
    end
    search
  end
end
