# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Introspectors::ViewIntrospector do
  let(:introspector) { described_class.new(Rails.application) }

  describe "#call" do
    subject(:result) { introspector.call }

    it "does not return an error" do
      expect(result).not_to have_key(:error)
    end

    it "discovers layouts as file names only" do
      expect(result[:layouts]).to include("application.html.erb")
      result[:layouts].each do |layout|
        expect(layout).not_to include("/")
      end
    end

    it "does not include directories in layouts" do
      result[:layouts].each do |layout|
        full_path = File.join(Rails.root, "app/views/layouts", layout)
        expect(File.file?(full_path)).to be(true), "Expected #{layout} to be a file, not a directory"
      end
    end

    it "discovers templates grouped by controller" do
      expect(result[:templates]).to have_key("posts")
      expect(result[:templates]["posts"]).to include("index.html.erb")
      expect(result[:templates]["posts"]).to include("show.html.erb")
    end

    it "excludes partials from templates" do
      result[:templates].each do |_controller, templates|
        templates.each do |t|
          expect(t).not_to start_with("_")
        end
      end
    end

    it "excludes layouts from templates" do
      expect(result[:templates]).not_to have_key("layouts")
    end

    it "discovers partials in per_controller" do
      expect(result[:partials][:per_controller]).to have_key("posts")
      expect(result[:partials][:per_controller]["posts"]).to include("_post.html.erb")
    end

    it "returns shared partials as sorted array" do
      expect(result[:partials][:shared]).to be_an(Array)
    end

    it "extracts helpers with methods" do
      helper_files = result[:helpers].map { |h| h[:file] }
      expect(helper_files).to include("application_helper.rb", "posts_helper.rb")

      app_helper = result[:helpers].find { |h| h[:file] == "application_helper.rb" }
      expect(app_helper[:methods]).to include("page_title")

      posts_helper = result[:helpers].find { |h| h[:file] == "posts_helper.rb" }
      expect(posts_helper[:methods]).to include("post_excerpt")
    end

    it "detects erb template engine" do
      expect(result[:template_engines]).to include("erb")
    end

    it "discovers view components from app/components" do
      expect(result[:view_components]).to include("alert_component", "card_component")
    end

    it "detects form builders used in views" do
      expect(result[:form_builders_detected]).to be_a(Hash)
      expect(result[:form_builders_detected]["form_with"]).to be >= 1
    end

    it "returns component_usage as array" do
      expect(result[:component_usage]).to be_an(Array)
    end

    it "returns layout_mapping as array" do
      expect(result[:layout_mapping]).to be_an(Array)
      expect(result[:layout_mapping]).to include("application")
    end

    context "with component render calls in views" do
      let(:fixture_view) { File.join(Rails.root, "app/views/posts/components_test.html.erb") }

      before do
        File.write(fixture_view, <<~ERB)
          <%= render AlertComponent.new(message: "Hello") %>
          <%= render CardComponent.new(title: "World") %>
        ERB
      end

      after { FileUtils.rm_f(fixture_view) }

      it "detects component usage from render calls" do
        expect(result[:component_usage]).to include("AlertComponent", "CardComponent")
      end
    end
  end
end
