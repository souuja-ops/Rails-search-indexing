class AddArticleCountToSearches < ActiveRecord::Migration[6.0]
  def change
    add_column :searches, :article_count, :integer, default: 0
    add_column :searches, :zero_article_count, :integer, default: 0
  end
end
