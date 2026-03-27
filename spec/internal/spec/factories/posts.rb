FactoryBot.define do
  factory :post do
    sequence(:title) { |n| "Post #{n}" }
    body { "This is the body of the post." }
    association :user

    trait :published do
      published { true }
    end

    trait :draft do
      published { false }
    end

    trait :with_long_body do
      body { "A" * 500 }
    end
  end
end
