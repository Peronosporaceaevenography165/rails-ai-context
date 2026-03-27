# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Introspectors::ViewTemplateIntrospector do
  let(:introspector) { described_class.new(Rails.application) }

  describe "#call" do
    subject(:result) { introspector.call }

    it "does not return an error" do
      expect(result).not_to have_key(:error)
    end

    it "returns templates hash" do
      expect(result[:templates]).to be_a(Hash)
    end

    it "returns partials hash" do
      expect(result[:partials]).to be_a(Hash)
    end

    it "discovers templates in posts directory" do
      expect(result[:templates].keys).to include("posts/index.html.erb")
      expect(result[:templates].keys).to include("posts/show.html.erb")
    end

    it "excludes partials from templates" do
      template_names = result[:templates].keys
      expect(template_names.none? { |n| File.basename(n).start_with?("_") }).to be true
    end

    it "discovers partials" do
      expect(result[:partials].keys).to include("posts/_post.html.erb")
    end

    it "counts lines for templates" do
      index = result[:templates]["posts/index.html.erb"]
      expect(index[:lines]).to be > 0
    end

    it "extracts partial references from templates" do
      index = result[:templates]["posts/index.html.erb"]
      expect(index[:partials]).to be_an(Array)
    end

    it "extracts stimulus references from templates" do
      show = result[:templates]["posts/show.html.erb"]
      expect(show[:stimulus]).to be_an(Array)
    end

    it "excludes layouts from templates" do
      template_names = result[:templates].keys
      expect(template_names.none? { |n| n.include?("layouts/") }).to be true
    end

    describe "form_builders" do
      it "detects form_with usage in views" do
        form_builders = result[:ui_patterns][:form_builders]
        expect(form_builders).to be_a(Hash)
        expect(form_builders[:form_with]).to be >= 1
      end

      it "omits builders with zero count" do
        form_builders = result[:ui_patterns][:form_builders]
        form_builders.each_value do |count|
          expect(count).to be > 0
        end
      end
    end

    describe "semantic_html" do
      it "detects semantic HTML elements in views" do
        semantic = result[:ui_patterns][:semantic_html]
        expect(semantic).to be_a(Hash)
        expect(semantic[:nav]).to be >= 1
      end

      it "detects article elements" do
        semantic = result[:ui_patterns][:semantic_html]
        expect(semantic[:article]).to be >= 1 if semantic.key?(:article)
      end

      it "detects section elements" do
        semantic = result[:ui_patterns][:semantic_html]
        expect(semantic[:section]).to be >= 1
      end
    end

    describe "accessibility_patterns" do
      it "detects ARIA attributes in views" do
        a11y = result[:ui_patterns][:accessibility_patterns]
        expect(a11y).to be_a(Hash)
        expect(a11y[:aria_attributes]).to be >= 1
      end

      it "detects role attributes in views" do
        a11y = result[:ui_patterns][:accessibility_patterns]
        expect(a11y[:roles]).to be >= 1
      end

      it "detects sr-only usage in views" do
        a11y = result[:ui_patterns][:accessibility_patterns]
        expect(a11y[:sr_only]).to be >= 1
      end
    end
  end
end
