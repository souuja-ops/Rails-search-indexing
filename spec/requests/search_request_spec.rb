require "rails_helper"

RSpec.describe "Search", type: :request do
  before(:each) do
    DatabaseCleaner.start

    create(:article, { title: "How do I cancel my subscription?" })
    create(:article, { title: "How do I cancel my account?" })
    create(:article, { title: "Can I upgrade my account?" })
    create(:article, { title: "Can you help me?" })
    create(:article, { title: "I don't know how to enroll a new person." })
    create(:article, { title: "Is it possible to generate new users?" })
  end

  after(:each) do
    DatabaseCleaner.clean
  end

  describe "GET /search" do
    before :each do
      get search_path, params: { term: "how" }, headers: { "Accept" => "application/json" }
    end

    it "works" do
      expect(response).to have_http_status(200)
    end

    it "returns the right count" do
      json_response = JSON.parse(response.body)
      expect(json_response.count).to eq 3
    end

    it "returns the right articles" do
      titles = [
        "How do I cancel my subscription?",
        "How do I cancel my account?",
        "I don't know how to enroll a new person.",
      ]
      json_response = JSON.parse(response.body)
      titles.each do |title|
        expect(response.body).to include title
      end
    end
  end

  describe "GET /search with casing" do
    it "is case insensitive" do
      get search_path, params: { term: "how" }, headers: { "Accept" => "application/json" }
      lower_response = response.body
      get search_path, params: { term: "How" }, headers: { "Accept" => "application/json" }
      not_lower_response = response.body

      expect(lower_response).to eq not_lower_response
    end
  end
end
