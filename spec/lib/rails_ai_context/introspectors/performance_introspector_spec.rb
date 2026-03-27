# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Introspectors::PerformanceIntrospector do
  let(:introspector) { described_class.new(Rails.application) }

  describe "#call" do
    subject(:result) { introspector.call }

    it "does not return an error" do
      expect(result).not_to have_key(:error)
    end

    it "returns n_plus_one_risks as array" do
      expect(result[:n_plus_one_risks]).to be_an(Array)
    end

    it "returns missing_counter_cache as array" do
      expect(result[:missing_counter_cache]).to be_an(Array)
    end

    it "returns missing_fk_indexes as array" do
      expect(result[:missing_fk_indexes]).to be_an(Array)
    end

    it "detects Model.all in controllers" do
      # PostsController uses Post.all in index action
      expect(result[:model_all_in_controllers]).to be_an(Array)
      models = result[:model_all_in_controllers].map { |f| f[:model] }
      expect(models).to include("Post")
    end

    it "provides suggestions for Model.all findings" do
      finding = result[:model_all_in_controllers].find { |f| f[:model] == "Post" }
      expect(finding[:suggestion]).to include("pagination")
    end

    it "detects eager load candidates" do
      expect(result[:eager_load_candidates]).to be_an(Array)
    end

    it "builds a summary with counts" do
      expect(result[:summary]).to be_a(Hash)
      expect(result[:summary][:total_issues]).to be_an(Integer)
      expect(result[:summary][:model_all_in_controllers]).to be >= 1
    end
  end
end
