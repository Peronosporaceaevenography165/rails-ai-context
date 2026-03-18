ActiveRecord::Schema[7.1].define(version: 2024_01_15_000000) do
  create_table "users" do |t|
    t.string "email"
    t.string "name"
    t.integer "role"
    t.timestamps
  end

  create_table "posts" do |t|
    t.string "title"
    t.text "body"
    t.references "user"
    t.timestamps
  end
end
