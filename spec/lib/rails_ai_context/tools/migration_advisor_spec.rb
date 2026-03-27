# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Tools::MigrationAdvisor do
  describe ".call" do
    before do
      allow(described_class).to receive(:cached_context).and_return({
        schema: {
          tables: {
            "users" => {
              columns: [
                { name: "email", type: "string" },
                { name: "name", type: "string" }
              ]
            },
            "posts" => {
              columns: [
                { name: "title", type: "string" },
                { name: "user_id", type: "integer" }
              ]
            }
          }
        },
        models: {
          User: { associations: [ { macro: :has_many, name: :posts, class_name: "Post" } ] },
          Post: { associations: [ { macro: :belongs_to, name: :user, class_name: "User" } ] }
        }
      })
    end

    it "generates add_column migration" do
      response = described_class.call(action: "add_column", table: "users", column: "phone", type: "string")
      text = response.content.first[:text]
      expect(text).to include("add_column :users, :phone, :string")
      expect(text).to include("Reversible:** Yes")
    end

    it "warns when adding a column that already exists" do
      response = described_class.call(action: "add_column", table: "users", column: "email", type: "string")
      text = response.content.first[:text]
      expect(text).to include("already exists")
      expect(text).to include("DuplicateColumn")
    end

    it "warns when adding an association FK that already exists" do
      response = described_class.call(action: "add_association", table: "posts", column: "user")
      text = response.content.first[:text]
      expect(text).to include("already exists")
    end

    it "warns when removing a nonexistent column" do
      response = described_class.call(action: "remove_column", table: "users", column: "totally_fake")
      text = response.content.first[:text]
      expect(text).to include("does not exist")
    end

    it "warns when renaming a nonexistent column" do
      response = described_class.call(action: "rename_column", table: "users", column: "totally_fake", new_name: "still_fake")
      text = response.content.first[:text]
      expect(text).to include("does not exist")
    end

    it "warns when adding index on nonexistent column" do
      response = described_class.call(action: "add_index", table: "users", column: "totally_fake")
      text = response.content.first[:text]
      expect(text).to include("does not exist")
    end

    it "warns when changing type of nonexistent column" do
      response = described_class.call(action: "change_type", table: "users", column: "totally_fake", type: "text")
      text = response.content.first[:text]
      expect(text).to include("does not exist")
    end

    it "warns when removing column from nonexistent table" do
      response = described_class.call(action: "remove_column", table: "nonexistent_table", column: "name")
      text = response.content.first[:text]
      expect(text).to include("not found")
    end

    it "generates remove_column migration with warning" do
      response = described_class.call(action: "remove_column", table: "users", column: "name")
      text = response.content.first[:text]
      expect(text).to include("remove_column :users, :name")
      expect(text).to include("Data loss")
    end

    it "generates add_index migration" do
      response = described_class.call(action: "add_index", table: "posts", column: "title")
      text = response.content.first[:text]
      expect(text).to include("add_index :posts, :title")
    end

    it "generates add_association migration" do
      response = described_class.call(action: "add_association", table: "posts", column: "categories")
      text = response.content.first[:text]
      expect(text).to include("add_reference")
      expect(text).to include("belongs_to")
      expect(text).to include("has_many")
    end

    it "generates create_table migration" do
      response = described_class.call(action: "create_table", table: "tags", column: "name:string,color:string")
      text = response.content.first[:text]
      expect(text).to include("create_table :tags")
      expect(text).to include("t.string :name")
    end

    it "warns about irreversible change_type" do
      response = described_class.call(action: "change_type", table: "posts", column: "title", type: "text")
      text = response.content.first[:text]
      expect(text).to include("Reversible:** No")
      expect(text).to include("data loss")
    end

    it "shows affected models" do
      response = described_class.call(action: "add_column", table: "users", column: "age", type: "integer")
      text = response.content.first[:text]
      expect(text).to include("Affected Models")
    end

    it "generates rename_column with new_name parameter" do
      response = described_class.call(action: "rename_column", table: "users", column: "name", new_name: "full_name")
      text = response.content.first[:text]
      expect(text).to include("rename_column :users, :name, :full_name")
      expect(text).to include("Reversible:** Yes")
      expect(text).to include(":name")
      expect(text).to include(":full_name")
    end

    it "falls back to type param for rename_column backward compat" do
      response = described_class.call(action: "rename_column", table: "users", column: "name", type: "full_name")
      text = response.content.first[:text]
      expect(text).to include("rename_column :users, :name, :full_name")
    end
  end
end
