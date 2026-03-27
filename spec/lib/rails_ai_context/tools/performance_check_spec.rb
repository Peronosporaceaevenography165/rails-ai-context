# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Tools::PerformanceCheck do
  describe ".call" do
    let(:performance_data) do
      {
        n_plus_one_risks: [
          { model: "Post", association: "comments", controller: "app/controllers/posts_controller.rb",
            suggestion: "Add .includes(:comments) to the query" }
        ],
        missing_counter_cache: [],
        missing_fk_indexes: [
          { table: "comments", column: "user_id", suggestion: "add_index :comments, :user_id" },
          { table: "comments", column: "post_id", suggestion: "add_index :comments, :post_id" }
        ],
        model_all_in_controllers: [
          { controller: "app/controllers/posts_controller.rb", model: "Post",
            suggestion: "Post.all loads all records into memory. Consider pagination or scoping." }
        ],
        eager_load_candidates: [
          { model: "Post", associations: %w[comments tags],
            suggestion: "Consider eager loading when rendering Post with associations: comments, tags" }
        ],
        summary: {
          total_issues: 4, n_plus_one_risks: 1, missing_counter_cache: 0,
          missing_fk_indexes: 2, model_all_in_controllers: 1, eager_load_candidates: 1
        }
      }
    end

    before do
      allow(described_class).to receive(:cached_context).and_return({ performance: performance_data })
    end

    it "returns summary counts" do
      response = described_class.call(detail: "summary")
      text = response.content.first[:text]
      expect(text).to include("N+1 risks: 1")
      expect(text).to include("Model.all in controllers: 1")
    end

    it "returns standard detail with suggestions" do
      response = described_class.call(detail: "standard")
      text = response.content.first[:text]
      expect(text).to include("includes(:comments)")
      expect(text).to include("pagination")
    end

    it "filters by model name for model-keyed items" do
      response = described_class.call(model: "Post")
      text = response.content.first[:text]
      expect(text).to include("Post")
    end

    it "filters by model name and matches table-keyed items" do
      response = described_class.call(model: "Comment", detail: "standard")
      text = response.content.first[:text]
      expect(text).to include("comments")
    end

    it "filters by category" do
      response = described_class.call(category: "indexes")
      text = response.content.first[:text]
      expect(text).to include("FK Indexes")
      expect(text).not_to include("N+1")
    end

    it "shows full detail with context" do
      response = described_class.call(detail: "full")
      text = response.content.first[:text]
      expect(text).to include("posts_controller.rb")
    end
  end
end
