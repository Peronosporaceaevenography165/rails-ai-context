# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Configuration do
  let(:config) { described_class.new }

  it "has sensible defaults" do
    expect(config.server_name).to eq("rails-ai-context")
    expect(config.http_port).to eq(6029)
    expect(config.http_bind).to eq("127.0.0.1")
    expect(config.auto_mount).to eq(false)
    expect(config.max_association_depth).to eq(2)
  end

  it "excludes internal Rails models by default" do
    expect(config.excluded_models).to include("ApplicationRecord")
    expect(config.excluded_models).to include("ActiveStorage::Blob")
  end

  it "is configurable" do
    config.server_name = "my-app"
    config.http_port = 8080
    config.auto_mount = true

    expect(config.server_name).to eq("my-app")
    expect(config.http_port).to eq(8080)
    expect(config.auto_mount).to eq(true)
  end

  describe RailsAiContext do
    it "supports block configuration" do
      RailsAiContext.configure do |c|
        c.server_name = "test-app"
      end

      expect(RailsAiContext.configuration.server_name).to eq("test-app")
    ensure
      # Reset
      RailsAiContext.configuration = RailsAiContext::Configuration.new
    end
  end
end
