# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Tools::BaseTool do
  describe ".text_response truncation" do
    before do
      @original_max = RailsAiContext.configuration.max_tool_response_chars
      RailsAiContext.configuration.max_tool_response_chars = 100
    end

    after do
      RailsAiContext.configuration.max_tool_response_chars = @original_max
    end

    it "truncates responses exceeding max chars" do
      long_text = "x" * 200
      result = described_class.text_response(long_text)
      text = result.content.first[:text]
      expect(text).to include("Response truncated")
      expect(text).to include("200 chars")
    end

    it "does not truncate short responses" do
      short_text = "hello"
      result = described_class.text_response(short_text)
      text = result.content.first[:text]
      expect(text).to eq("hello")
    end

    it "includes hint to use detail:summary" do
      long_text = "x" * 200
      result = described_class.text_response(long_text)
      text = result.content.first[:text]
      expect(text).to include('detail:"summary"')
    end
  end

  describe ".reset_all_caches!" do
    it "calls reset_cache! on every registered tool" do
      RailsAiContext::Server::TOOLS.each do |tool_class|
        expect(tool_class).to receive(:reset_cache!)
      end

      described_class.reset_all_caches!
    end

    it "resets all 9 tools" do
      # Populate a cache on one tool to verify it gets cleared
      tool = RailsAiContext::Server::TOOLS.first
      tool.instance_variable_set(:@cached_context, { fake: true })
      tool.instance_variable_set(:@cache_timestamp, 999)

      described_class.reset_all_caches!

      expect(tool.instance_variable_get(:@cached_context)).to be_nil
      expect(tool.instance_variable_get(:@cache_timestamp)).to be_nil
    end
  end
end
