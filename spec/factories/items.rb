FactoryBot.define do
  factory :item do
    name { "Cordless Drill" }
    category { "Tools" }
    description { "18V drill with bits" }
    condition { "good" }
    available { true }
  end
end
