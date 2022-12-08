20.times do
  Article.create(title: Faker::Movies::HitchhikersGuideToTheGalaxy.unique.quote)
end
