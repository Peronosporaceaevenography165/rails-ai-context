# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Tools::DependencyGraph do
  describe ".call" do
    let(:models_data) do
      {
        User: {
          associations: [
            { macro: :has_many, name: :posts, class_name: "Post" },
            { macro: :has_many, name: :comments, class_name: "Comment" }
          ]
        },
        Post: {
          associations: [
            { macro: :belongs_to, name: :user, class_name: "User" },
            { macro: :has_many, name: :comments, class_name: "Comment" }
          ]
        },
        Comment: {
          associations: [
            { macro: :belongs_to, name: :post, class_name: "Post" },
            { macro: :belongs_to, name: :user, class_name: "User" }
          ]
        }
      }
    end

    before do
      allow(described_class).to receive(:cached_context).and_return({ models: models_data })
    end

    it "generates mermaid diagram" do
      response = described_class.call(format: "mermaid")
      text = response.content.first[:text]
      expect(text).to include("```mermaid")
      expect(text).to include("graph LR")
      expect(text).to include("User")
      expect(text).to include("Post")
    end

    it "generates text output" do
      response = described_class.call(format: "text")
      text = response.content.first[:text]
      expect(text).to include("has_many")
      expect(text).to include("belongs_to")
    end

    it "centers graph on a model" do
      response = described_class.call(model: "Post", format: "text")
      text = response.content.first[:text]
      expect(text).to include("Post")
    end

    it "returns not-found for unknown model" do
      response = described_class.call(model: "Unknown")
      text = response.content.first[:text]
      expect(text).to include("not found")
    end

    it "respects depth parameter" do
      response = described_class.call(model: "Post", depth: 1, format: "text")
      text = response.content.first[:text]
      expect(text).to include("Post")
    end
  end
end
