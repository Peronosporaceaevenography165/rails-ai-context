# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Introspectors::AccessibilityIntrospector do
  let(:introspector) { described_class.new(Rails.application) }

  describe "#call" do
    subject(:result) { introspector.call }

    it "does not return an error" do
      expect(result).not_to have_key(:error)
    end

    it "detects aria attributes" do
      expect(result[:aria_attributes]).to be_a(Hash)
      expect(result[:aria_attributes].values.sum).to be > 0
    end

    it "detects aria-label usage" do
      expect(result[:aria_attributes]).to have_key("aria-label")
    end

    it "detects aria-hidden usage" do
      expect(result[:aria_attributes]).to have_key("aria-hidden")
    end

    it "detects roles" do
      expect(result[:roles]).to be_a(Hash)
      expect(result[:roles].keys).to include("alert")
    end

    it "detects semantic HTML elements" do
      expect(result[:semantic_elements]).to be_a(Hash)
      # Our fixtures include nav, main, header, footer, article
      expect(result[:semantic_elements].keys).to include("nav")
      expect(result[:semantic_elements].keys).to include("main")
      expect(result[:semantic_elements].keys).to include("article")
    end

    it "counts screen reader text patterns" do
      expect(result[:screen_reader_text]).to be_a(Hash)
      expect(result[:screen_reader_text][:sr_only]).to be >= 1
    end

    it "analyzes label associations" do
      expect(result[:labels]).to be_a(Hash)
      expect(result[:labels][:aria_label]).to be > 0
    end

    it "extracts landmark roles" do
      expect(result[:landmarks]).to be_a(Hash)
      expect(result[:landmarks].keys).to include("navigation")
    end

    it "builds an accessibility summary with score" do
      expect(result[:summary]).to be_a(Hash)
      expect(result[:summary][:files_scanned]).to be > 0
      expect(result[:summary][:accessibility_score]).to be_between(1, 5)
      expect(result[:summary][:score_label]).to be_a(String)
    end
  end
end
