# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Tools::GetComponentCatalog do
  describe ".call" do
    let(:component_data) do
      {
        components: [
          {
            name: "AlertComponent", type: :view_component,
            file: "app/components/alert_component.rb",
            props: [ { name: "type", default: ":info" }, { name: "dismissible", default: "false" } ],
            slots: [ { name: "icon", type: :one }, { name: "actions", type: :many } ],
            sidecar_assets: [ "alert_component.html.erb" ]
          },
          {
            name: "CardComponent", type: :view_component,
            file: "app/components/card_component.rb",
            props: [ { name: "variant", default: ":default" } ],
            slots: [ { name: "header", type: :one }, { name: "footer", type: :one }, { name: "badges", type: :many } ],
            sidecar_assets: [ "card_component.html.erb" ]
          }
        ],
        summary: { total: 2, view_component: 2, phlex: 0, with_slots: 2, with_previews: 0 }
      }
    end

    before do
      allow(described_class).to receive(:cached_context).and_return({ components: component_data })
    end

    it "returns summary detail level" do
      response = described_class.call(detail: "summary")
      text = response.content.first[:text]
      expect(text).to include("AlertComponent")
      expect(text).to include("CardComponent")
      expect(text).to include("2 slots")
    end

    it "returns standard detail with props and slots" do
      response = described_class.call(detail: "standard")
      text = response.content.first[:text]
      expect(text).to include("Props")
      expect(text).to include("type")
      expect(text).to include("Slots")
      expect(text).to include("icon")
    end

    it "filters by component name" do
      response = described_class.call(component: "alert")
      text = response.content.first[:text]
      expect(text).to include("AlertComponent")
      expect(text).not_to include("CardComponent")
    end

    it "returns not-found for unknown component" do
      response = described_class.call(component: "nonexistent")
      text = response.content.first[:text]
      expect(text).to include("not found")
    end

    it "generates usage examples in full mode" do
      response = described_class.call(component: "alert", detail: "full")
      text = response.content.first[:text]
      expect(text).to include("Usage")
      expect(text).to include("render")
    end
  end
end
