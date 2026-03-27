# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Introspectors::ControllerIntrospector do
  let(:introspector) { described_class.new(Rails.application) }

  describe "#call" do
    subject(:result) { introspector.call }

    it "does not return an error" do
      expect(result).not_to have_key(:error)
    end

    it "returns a controllers hash" do
      expect(result).to have_key(:controllers)
      expect(result[:controllers]).to be_a(Hash)
    end

    it "discovers PostsController" do
      expect(result[:controllers]).to have_key("PostsController")
    end

    it "extracts all CRUD actions from PostsController" do
      actions = result[:controllers]["PostsController"][:actions]
      expect(actions).to include("index", "show", "new", "create", "edit", "update", "destroy")
    end

    it "extracts filter with correct kind" do
      filters = result[:controllers]["PostsController"][:filters]
      set_post = filters.find { |f| f[:name] == "set_post" }
      expect(set_post).not_to be_nil
      expect(set_post[:kind]).to eq("before")
    end

    it "extracts parent class" do
      expect(result[:controllers]["PostsController"][:parent_class]).to eq("ApplicationController")
    end

    it "extracts strong params methods" do
      params = result[:controllers]["PostsController"][:strong_params]
      expect(params).to eq([ "post_params" ])
    end

    it "extracts respond_to formats from respond_to blocks" do
      formats = result[:controllers]["PostsController"][:respond_to_formats]
      expect(formats).to contain_exactly("html", "json", "turbo_stream")
    end

    it "detects API controllers" do
      expect(result[:controllers]).to have_key("Api::V1::BaseController")
      api = result[:controllers]["Api::V1::BaseController"]
      expect(api[:api_controller]).to be true
      expect(api[:parent_class]).to include("API")
    end

    it "marks non-API controllers as not api_controller" do
      expect(result[:controllers]["PostsController"][:api_controller]).to be false
    end

    it "excludes ApplicationController" do
      expect(result[:controllers]).not_to have_key("ApplicationController")
    end

    it "extracts concerns array" do
      concerns = result[:controllers]["PostsController"][:concerns]
      expect(concerns).to be_an(Array)
    end

    it "returns turbo_stream_actions for PostsController" do
      turbo_actions = result[:controllers]["PostsController"][:turbo_stream_actions]
      expect(turbo_actions).to include("create")
    end

    context "with a controller that has rescue_from and rate_limit" do
      let(:fixture_ctrl) { File.join(Rails.root, "app/controllers/widgets_controller.rb") }

      before do
        File.write(fixture_ctrl, <<~RUBY)
          class WidgetsController < ApplicationController
            rescue_from ActiveRecord::RecordNotFound, with: :not_found
            rescue_from ActionController::ParameterMissing, with: :bad_request
            rate_limit to: 10, within: 1.minute

            def index
              @widgets = []
            end

            private

            def not_found
              head :not_found
            end

            def bad_request
              head :bad_request
            end
          end
        RUBY
      end

      after { FileUtils.rm_f(fixture_ctrl) }

      it "extracts rescue_from declarations" do
        load fixture_ctrl
        rescue_from = result[:controllers]["WidgetsController"][:rescue_from]
        expect(rescue_from).to be_an(Array)
        not_found_entry = rescue_from.find { |r| r[:handler] == "not_found" }
        expect(not_found_entry).not_to be_nil
      end

      it "extracts rate_limit macro" do
        load fixture_ctrl
        rate_limit = result[:controllers]["WidgetsController"][:rate_limit]
        expect(rate_limit).to include("10")
      end
    end

    context "with a controller that has complex respond_to" do
      let(:fixture_ctrl) { File.join(Rails.root, "app/controllers/items_controller.rb") }

      before do
        File.write(fixture_ctrl, <<~RUBY)
          class ItemsController < ApplicationController
            def index
              @items = []
              respond_to do |format|
                if @items.empty?
                  format.html { render :empty }
                end
                format.json { render json: @items }
                format.xml { render xml: @items }
              end
            end
          end
        RUBY
      end

      after { FileUtils.rm_f(fixture_ctrl) }

      it "extracts all formats including those after nested end" do
        # Force controller discovery by loading the class
        load fixture_ctrl
        formats = result[:controllers]["ItemsController"][:respond_to_formats]
        expect(formats).to contain_exactly("html", "json", "xml")
      end
    end
  end
end
