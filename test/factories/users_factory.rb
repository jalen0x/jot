FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    password { "password123" }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }

    trait :github_connected do
      provider { "github" }
      uid { "github-#{SecureRandom.hex(8)}" }
    end
  end
end
