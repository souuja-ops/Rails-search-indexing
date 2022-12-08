FactoryBot.define do
  factory :article do
    title { Faker::Movies::HitchhikersGuideToTheGalaxy.quote }
  end
end
