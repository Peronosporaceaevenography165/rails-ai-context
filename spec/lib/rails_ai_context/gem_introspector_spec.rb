# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Introspectors::GemIntrospector do
  let(:fixture_path) { File.expand_path("../../fixtures", __FILE__) }
  let(:app) { double("app", root: Pathname.new(fixture_path)) }
  let(:introspector) { described_class.new(app) }

  describe "#call" do
    before do
      FileUtils.mkdir_p(fixture_path)
      File.write(File.join(fixture_path, "Gemfile.lock"), <<~LOCK)
        GEM
          remote: https://rubygems.org/
          specs:
            devise (4.9.3)
            pg (1.5.4)
            sidekiq (7.2.0)
            turbo-rails (2.0.4)
            rspec-rails (6.1.0)
            rails (7.1.3)

        PLATFORMS
          ruby

        DEPENDENCIES
          devise
          pg
          sidekiq
      LOCK
    end

    after do
      FileUtils.rm_f(File.join(fixture_path, "Gemfile.lock"))
    end

    it "counts total gems" do
      result = introspector.call
      expect(result[:total_gems]).to eq(6)
    end

    it "detects notable gems" do
      result = introspector.call
      names = result[:notable_gems].map { |g| g[:name] }
      expect(names).to include("devise", "pg", "sidekiq", "turbo-rails", "rspec-rails")
    end

    it "categorizes gems correctly" do
      result = introspector.call
      expect(result[:categories]["auth"]).to include("devise")
      expect(result[:categories]["database"]).to include("pg")
      expect(result[:categories]["jobs"]).to include("sidekiq")
    end

    it "includes version info" do
      result = introspector.call
      devise = result[:notable_gems].find { |g| g[:name] == "devise" }
      expect(devise[:version]).to eq("4.9.3")
    end
  end

  describe "new NOTABLE_GEMS entries" do
    before do
      FileUtils.mkdir_p(fixture_path)
      File.write(File.join(fixture_path, "Gemfile.lock"), <<~LOCK)
        GEM
          remote: https://rubygems.org/
          specs:
            solid_queue (1.0.0)
            solid_cache (1.0.0)
            solid_cable (1.0.0)
            kamal (2.0.0)
            thruster (0.1.0)
            propshaft (1.0.0)
            litestack (0.4.0)
            dry-validation (1.10.0)
            dry-types (1.7.0)
            dry-struct (1.6.0)
            dry-monads (1.6.0)
            phlex-rails (2.0.0)
            view_component (3.0.0)
            lookbook (2.0.0)
            mission_control-jobs (0.3.0)
            noticed (2.0.0)
            authentication-zero (3.0.0)
            alba (3.0.0)
            blueprinter (1.0.0)
            oj (3.16.0)
            puma (6.4.0)
            falcon (0.43.0)
            anycable (1.4.0)
            kredis (1.7.0)
            motor-admin (0.4.0)
            avo (3.0.0)
            madmin (1.0.0)
            trestle (0.9.0)
      LOCK
    end

    after do
      FileUtils.rm_f(File.join(fixture_path, "Gemfile.lock"))
    end

    it "detects all newly added notable gems" do
      result = introspector.call
      names = result[:notable_gems].map { |g| g[:name] }
      expect(names).to include(
        "solid_queue", "solid_cache", "solid_cable",
        "kamal", "thruster", "propshaft", "litestack",
        "dry-validation", "dry-types", "dry-struct", "dry-monads",
        "phlex-rails", "view_component", "lookbook",
        "mission_control-jobs", "noticed", "authentication-zero",
        "alba", "blueprinter", "oj",
        "puma", "falcon", "anycable", "kredis",
        "motor-admin", "avo", "madmin", "trestle"
      )
    end

    it "categorizes new gems correctly" do
      result = introspector.call
      cats = result[:categories]
      expect(cats["validation"]).to include("dry-validation")
      expect(cats["server"]).to include("puma")
      expect(cats["deploy"]).to include("thruster")
      expect(cats["notifications"]).to include("noticed")
    end
  end

  describe "new API and auth NOTABLE_GEMS entries" do
    before do
      FileUtils.mkdir_p(fixture_path)
      File.write(File.join(fixture_path, "Gemfile.lock"), <<~LOCK)
        GEM
          remote: https://rubygems.org/
          specs:
            devise-jwt (0.11.0)
            rswag-api (2.10.0)
            rswag-ui (2.10.0)
            grape-swagger (2.0.0)
            apipie-rails (1.0.0)
            hotwire-native-rails (1.0.0)

        PLATFORMS
          ruby
      LOCK
    end

    after do
      FileUtils.rm_f(File.join(fixture_path, "Gemfile.lock"))
    end

    it "detects all newly added gems" do
      result = introspector.call
      names = result[:notable_gems].map { |g| g[:name] }
      expect(names).to include(
        "devise-jwt", "rswag-api", "rswag-ui",
        "grape-swagger", "apipie-rails", "hotwire-native-rails"
      )
    end

    it "categorizes new gems correctly" do
      result = introspector.call
      cats = result[:categories]
      expect(cats["auth"]).to include("devise-jwt")
      expect(cats["api"]).to include("rswag-api", "rswag-ui", "grape-swagger", "apipie-rails")
      expect(cats["frontend"]).to include("hotwire-native-rails")
    end
  end

  context "when Gemfile.lock is missing" do
    let(:app) { double("app", root: Pathname.new("/nonexistent")) }

    it "returns an error" do
      result = introspector.call
      expect(result[:error]).to include("No Gemfile.lock")
    end
  end
end
