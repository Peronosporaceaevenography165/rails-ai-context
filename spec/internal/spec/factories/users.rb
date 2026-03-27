FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Test User" }
    role { :member }

    trait :admin do
      role { :admin }
      name { "Admin User" }
    end

    trait :active do
      active { true }
    end

    trait :inactive do
      active { false }
    end
  end
end
