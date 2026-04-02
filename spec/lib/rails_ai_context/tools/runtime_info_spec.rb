# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Tools::RuntimeInfo do
  before { described_class.reset_cache! }

  describe ".call" do
    it "returns an MCP::Tool::Response" do
      result = described_class.call
      expect(result).to be_a(MCP::Tool::Response)
    end

    it "includes Runtime Info header" do
      result = described_class.call(detail: "summary")
      text = result.content.first[:text]
      expect(text).to include("Runtime Info")
    end

    it "shows connection pool stats" do
      result = described_class.call(section: "connections")
      text = result.content.first[:text]
      expect(text).to include("Connection Pool")
      expect(text).to include("Pool size")
    end

    it "shows database section" do
      result = described_class.call(section: "database")
      text = result.content.first[:text]
      expect(text).to include("Database")
    end

    it "shows cache section" do
      result = described_class.call(section: "cache")
      text = result.content.first[:text]
      expect(text).to include("Cache")
    end

    it "shows jobs section" do
      result = described_class.call(section: "jobs")
      text = result.content.first[:text]
      expect(text).to include("Background Jobs")
    end

    it "filters to a single section" do
      result = described_class.call(section: "connections")
      text = result.content.first[:text]
      expect(text).to include("Connection Pool")
      expect(text).not_to include("Background Jobs")
      expect(text).not_to include("## Cache")
    end

    it "standard detail shows all sections" do
      result = described_class.call(detail: "standard")
      text = result.content.first[:text]
      expect(text).to include("Connection Pool")
      expect(text).to include("Database")
    end

    it "handles graceful degradation when Sidekiq not loaded" do
      result = described_class.call(section: "jobs")
      text = result.content.first[:text]
      expect(text).to include("not loaded")
    end

    it "has read-only annotations" do
      annotations = described_class.annotations_value
      expect(annotations.read_only_hint).to eq(true)
      expect(annotations.destructive_hint).to eq(false)
    end
  end
end
