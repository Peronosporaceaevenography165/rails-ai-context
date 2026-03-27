# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Introspectors::TurboIntrospector do
  let(:introspector) { described_class.new(Rails.application) }

  describe "#call" do
    subject(:result) { introspector.call }

    it "does not return an error" do
      expect(result).not_to have_key(:error)
    end

    it "discovers turbo frames with id and file" do
      expect(result[:turbo_frames]).to be_an(Array)
      frame = result[:turbo_frames].find { |f| f[:id] == "post" }
      expect(frame).not_to be_nil
      expect(frame[:file]).to eq("posts/show.html.erb")
    end

    it "discovers turbo stream templates" do
      expect(result[:turbo_streams]).to include("posts/create.turbo_stream.erb")
    end

    it "returns model_broadcasts as empty when no broadcasts in models" do
      expect(result[:model_broadcasts]).to eq([])
    end

    describe "morph_meta" do
      it "detects turbo-refresh-method morph meta tag in layouts" do
        expect(result[:morph_meta]).to be true
      end
    end

    describe "permanent_elements" do
      it "returns an array of elements with data-turbo-permanent" do
        expect(result[:permanent_elements]).to be_an(Array)
        expect(result[:permanent_elements].size).to be >= 2
      end

      it "extracts id from permanent elements" do
        element_with_id = result[:permanent_elements].find { |e| e[:id] == "main-content" }
        expect(element_with_id).not_to be_nil
      end

      it "includes permanent elements from view templates" do
        show_element = result[:permanent_elements].find { |e| e[:file] == "posts/show.html.erb" }
        expect(show_element).not_to be_nil
      end
    end

    describe "turbo_drive_settings" do
      it "returns a hash of turbo drive attribute counts" do
        expect(result[:turbo_drive_settings]).to be_a(Hash)
      end

      it "counts data-turbo-action occurrences" do
        expect(result[:turbo_drive_settings][:"data-turbo-action"]).to be >= 1
      end
    end

    describe "turbo_stream_responses" do
      it "returns an array of controller actions with turbo_stream responses" do
        expect(result[:turbo_stream_responses]).to be_an(Array)
      end

      it "detects format.turbo_stream in PostsController#create" do
        response = result[:turbo_stream_responses].find { |r| r[:controller] == "PostsController" && r[:action] == "create" }
        expect(response).not_to be_nil
      end
    end

    context "with a model that uses broadcasts" do
      let(:fixture_model) { File.join(Rails.root, "app/models/message.rb") }

      before do
        File.write(fixture_model, <<~RUBY)
          class Message < ApplicationRecord
            broadcasts_to :room
            broadcasts_refreshes_to :room
          end
        RUBY
      end

      after { FileUtils.rm_f(fixture_model) }

      it "detects model broadcasts" do
        broadcast = result[:model_broadcasts].find { |b| b[:model] == "Message" }
        expect(broadcast).not_to be_nil
        expect(broadcast[:methods]).to include("broadcasts_to", "broadcasts_refreshes_to")
      end
    end
  end
end
