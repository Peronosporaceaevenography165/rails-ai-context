# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Introspectors::ComponentIntrospector do
  let(:introspector) { described_class.new(Rails.application) }

  describe "#call" do
    subject(:result) { introspector.call }

    it "does not return an error" do
      expect(result).not_to have_key(:error)
    end

    it "discovers ViewComponent components" do
      names = result[:components].map { |c| c[:name] }
      expect(names).to include("AlertComponent", "CardComponent")
    end

    it "detects component type as view_component" do
      alert = result[:components].find { |c| c[:name] == "AlertComponent" }
      expect(alert[:type]).to eq(:view_component)
    end

    it "extracts renders_one slots" do
      alert = result[:components].find { |c| c[:name] == "AlertComponent" }
      slot_names = alert[:slots].select { |s| s[:type] == :one }.map { |s| s[:name] }
      expect(slot_names).to include("icon")
    end

    it "extracts renders_many slots" do
      alert = result[:components].find { |c| c[:name] == "AlertComponent" }
      slot_names = alert[:slots].select { |s| s[:type] == :many }.map { |s| s[:name] }
      expect(slot_names).to include("actions")
    end

    it "extracts initialize props" do
      alert = result[:components].find { |c| c[:name] == "AlertComponent" }
      prop_names = alert[:props].map { |p| p[:name] }
      expect(prop_names).to include("type", "dismissible")
    end

    it "extracts prop defaults" do
      alert = result[:components].find { |c| c[:name] == "AlertComponent" }
      type_prop = alert[:props].find { |p| p[:name] == "type" }
      expect(type_prop[:default]).to eq(":info")
    end

    it "detects sidecar template assets" do
      alert = result[:components].find { |c| c[:name] == "AlertComponent" }
      expect(alert[:sidecar_assets]).to include("alert_component.html.erb")
    end

    it "extracts card component slots" do
      card = result[:components].find { |c| c[:name] == "CardComponent" }
      slot_names = card[:slots].map { |s| s[:name] }
      expect(slot_names).to include("header", "footer", "badges")
    end

    it "detects Phlex components inheriting from a custom base class" do
      greeting = result[:components].find { |c| c[:name] == "GreetingComponent" }
      expect(greeting).not_to be_nil
      expect(greeting[:type]).to eq(:phlex)
    end

    it "builds a summary" do
      expect(result[:summary]).to be_a(Hash)
      expect(result[:summary][:total]).to be >= 2
      expect(result[:summary][:view_component]).to be >= 2
      expect(result[:summary][:with_slots]).to be >= 2
    end

    it "extracts enum values from hash constants" do
      badge = result[:components].find { |c| c[:name] == "BadgeComponent" }
      variant_prop = badge[:props].find { |p| p[:name] == "variant" }
      expect(variant_prop[:values]).to contain_exactly("primary", "secondary", "success")
    end

    it "extracts enum values from array constants" do
      badge = result[:components].find { |c| c[:name] == "BadgeComponent" }
      size_prop = badge[:props].find { |p| p[:name] == "size" }
      expect(size_prop[:values]).to contain_exactly("sm", "md", "lg")
    end

    it "extracts enum values from case statements" do
      alert = result[:components].find { |c| c[:name] == "AlertComponent" }
      type_prop = alert[:props].find { |p| p[:name] == "type" }
      expect(type_prop[:values]).to include("success", "error", "warning")
    end

    it "does not add values to props without enumerables" do
      greeting = result[:components].find { |c| c[:name] == "GreetingComponent" }
      name_prop = greeting[:props].find { |p| p[:name] == "name" }
      expect(name_prop).not_to have_key(:values)
    end
  end
end
