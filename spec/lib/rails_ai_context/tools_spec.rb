# frozen_string_literal: true

require "spec_helper"

RSpec.describe "MCP Tool Integration" do
  describe "tool definitions" do
    RailsAiContext::Server::TOOLS.each do |tool_class|
      describe tool_class.tool_name do
        it "has a valid MCP tool definition" do
          h = tool_class.to_h
          expect(h[:name]).to be_a(String)
          expect(h[:name]).not_to be_empty
          expect(h[:description]).to be_a(String)
          expect(h[:inputSchema]).to be_a(Hash)
        end

        it "has read-only annotations" do
          annotations = tool_class.annotations_value
          expect(annotations).not_to be_nil
          expect(annotations.read_only_hint).to eq(true)
          expect(annotations.destructive_hint).to eq(false)
        end
      end
    end
  end

  describe "MCP::Server" do
    it "builds with all tools registered" do
      server = RailsAiContext::Server.new(Rails.application).build
      expect(server.tools.size).to eq(6)
      expect(server.tools.keys).to contain_exactly(
        "rails_get_schema",
        "rails_get_routes",
        "rails_get_model_details",
        "rails_get_gems",
        "rails_search_code",
        "rails_get_conventions"
      )
    end
  end
end
