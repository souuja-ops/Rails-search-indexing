require "rails_helper"

RSpec.describe "Statistics", type: :request do
  before(:each) do
    DatabaseCleaner.start

    create(:article, { title: "How do I cancel my subscription?" })
    create(:article, { title: "How do I cancel my account?" })
    create(:article, { title: "Can I upgrade my account?" })
    create(:article, { title: "Can you help me?" })
    create(:article, { title: "I don't know how to enroll a new person." })
    create(:article, { title: "Is it possible to generate new users?" })

    fake_ip
  end

  after(:each) do
    DatabaseCleaner.clean
  end

  search_sample_1 = [
    { term: "how", sleep: 50 },
    { term: "how do i", sleep: 50 },
    { term: "how do i cancel", sleep: 50 },
    { term: "how do i cancel my acc", sleep: 50 },
    { term: "how do i cancel my", sleep: 3500 },
    { term: "how do i cancel my subscription", sleep: 50, submit: true },
  ]

  search_sample_2 = [
    { term: "canvas", sleep: 50, submit: true },
    { term: "roses", sleep: 50, submit: true },
    { term: "straw", sleep: 50, submit: true },
    { term: "canvas", sleep: 50, submit: true },
  ]

  search_sample_3 = [
    { term: "how", sleep: 50 },
    { term: "how do i cancel my subscription", sleep: 50, submit: true },
    { term: "how do i cancel my account", sleep: 50, submit: true, change_ip: true },
    { term: "how do i build a house", sleep: 50, submit: true },
    { term: "how do i cancel my account", sleep: 50, submit: true, change_ip: true },
    { term: "how do i cancel my account", sleep: 50, change_ip: true },
    { term: "how do i cancel my account", sleep: 50, change_ip: true },
    { term: "how do i cancel my account", sleep: 50, submit: true, change_ip: true },
    { term: "how do i cancel my account", sleep: 50, submit: true, change_ip: true },
    { term: "car", change_ip: true },
    { term: "bat", change_ip: true },
    { term: "window", change_ip: true },
    { term: "duck", change_ip: true },
  ]

  describe "GET /statistics" do
    it "has the right count of statistics" do
      type_searches_and_perform_worker search_sample_1, 0..5

      get search_statistics_path, headers: { "Accept" => "application/json" }
      json_response = JSON.parse(response.body)

      expect(json_response.count).to eq 3
    end

    it "has the right statistics" do
      type_searches_and_perform_worker search_sample_1, 0..5

      get search_statistics_path, headers: { "Accept" => "application/json" }
      json_response = JSON.parse(response.body)

      expect(json_response).to include(a_hash_including({ "term" => "how do i cancel my" }))
      expect(json_response).to include(a_hash_including({ "term" => "how do i cancel my subscription" }))
    end

    it "has only one term with right values for a single search" do
      type_searches_and_perform_worker search_sample_1, 0..0

      get search_statistics_path, headers: { "Accept" => "application/json" }
      json_response = JSON.parse(response.body)

      expect(json_response).to include(a_hash_including({
                                 "term" => "how",
                                 "count" => 1,
                                 "article_count" => 3,
                                 "zero_article_count" => 0,
                               }))
      expect(json_response.count).to eq 1
    end

    it "has statistics for zero results after invalid searches" do
      type_searches_and_perform_worker search_sample_2, 0..3

      get search_statistics_path, headers: { "Accept" => "application/json" }
      json_response = JSON.parse(response.body)

      expect(json_response).to match(
        [
          a_hash_including({
            "term" => "canvas",
            "count" => 2,
            "article_count" => 0,
            "zero_article_count" => 2,
          }),
          a_hash_including({
            "term" => "roses",
            "count" => 1,
            "article_count" => 0,
            "zero_article_count" => 1,
          }),
          a_hash_including({
            "term" => "straw",
            "count" => 1,
            "article_count" => 0,
            "zero_article_count" => 1,
          }),
        ]
      )
      expect(json_response.count).to eq 3
    end

    it "has the right count of statistics if more than user make a search" do
      type_searches_and_perform_worker search_sample_3, 0..3

      get search_statistics_path, headers: { "Accept" => "application/json" }
      json_response = JSON.parse(response.body)

      expect(json_response.count).to eq 3
    end

    it "has the right count of statistics if more than user make a single search each but with the same term" do
      type_searches_and_perform_worker search_sample_3, 4..8

      get search_statistics_path, headers: { "Accept" => "application/json" }
      json_response = JSON.parse(response.body)

      expect(json_response.count).to eq 1
    end

    it "has the right count of statistics if more than user make a single search each but with different terms" do
      type_searches_and_perform_worker search_sample_3, 9..12

      get search_statistics_path, headers: { "Accept" => "application/json" }
      json_response = JSON.parse(response.body)

      expect(json_response.count).to eq 4
    end
  end

  describe "DELETE /search/statistics" do
    it "redirects to GET /search/statistics" do
      delete search_statistics_path
      expect(response).to redirect_to(search_statistics_path)
    end

    it "has no statistics" do
      type_searches_and_perform_worker search_sample_1, 0..5

      get search_statistics_path, headers: { "Accept" => "application/json" }
      json_response = JSON.parse(response.body)

      expect(json_response).not_to be_empty

      delete search_statistics_path, headers: { "Accept" => "application/json" }

      get search_statistics_path, headers: { "Accept" => "application/json" }
      json_response = JSON.parse(response.body)

      expect(json_response).to be_empty
    end
  end

  def type_searches_and_perform_worker(array, slice = 0..-1)
    Timecop.freeze
    array[slice].each { |s| search_sleep s[:term], s[:sleep], s[:submit], s[:change_ip] }
    Timecop.return
    SearchWorker.new.perform
  end

  def fake_ip
    allow_any_instance_of(ActionDispatch::Request).to receive(:ip).and_return(
      ([nil] * 4).map { rand 0..255 }.join "."
    )
  end

  def search_sleep(term, time_to_sleep = nil, submit = false, change_ip = false)
    fake_ip if change_ip
    headers = { "Accept" => "application/json" }
    get search_path, params: { term: term, submit: !!submit }, headers: headers
    Timecop.travel(DateTime.now + (time_to_sleep.to_f / 1000).second) if time_to_sleep
  end
end
