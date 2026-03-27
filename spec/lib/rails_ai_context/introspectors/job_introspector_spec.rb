# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Introspectors::JobIntrospector do
  let(:introspector) { described_class.new(Rails.application) }

  describe "#call" do
    subject(:result) { introspector.call }

    it "returns jobs array" do
      expect(result[:jobs]).to be_an(Array)
    end

    it "returns mailers array" do
      expect(result[:mailers]).to be_an(Array)
    end

    it "returns channels array" do
      expect(result[:channels]).to be_an(Array)
    end
  end

  describe "source parsing fallback" do
    let(:fixture_job) { File.join(Rails.root, "app/jobs/cleanup_job.rb") }

    before do
      File.write(fixture_job, <<~RUBY)
        class CleanupJob < ApplicationJob
          queue_as :low_priority

          retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
          discard_on ActiveJob::DeserializationError

          def perform(user_id, options = {})
            # cleanup logic
          end
        end
      RUBY
    end

    after { FileUtils.rm_f(fixture_job) }

    it "extracts job details from source files" do
      jobs = introspector.send(:extract_jobs_from_source)
      cleanup = jobs.find { |j| j[:name] == "CleanupJob" }
      expect(cleanup).not_to be_nil
      expect(cleanup[:queue]).to eq("low_priority")
    end

    it "extracts retry_on declarations from source" do
      jobs = introspector.send(:extract_jobs_from_source)
      cleanup = jobs.find { |j| j[:name] == "CleanupJob" }
      expect(cleanup[:retry_on]).to be_an(Array)
      expect(cleanup[:retry_on].first).to include("ActiveRecord::Deadlocked")
    end

    it "extracts discard_on declarations from source" do
      jobs = introspector.send(:extract_jobs_from_source)
      cleanup = jobs.find { |j| j[:name] == "CleanupJob" }
      expect(cleanup[:discard_on]).to be_an(Array)
      expect(cleanup[:discard_on].first).to include("ActiveJob::DeserializationError")
    end

    it "extracts perform method signature from source" do
      jobs = introspector.send(:extract_jobs_from_source)
      cleanup = jobs.find { |j| j[:name] == "CleanupJob" }
      expect(cleanup[:perform_signature]).to eq("user_id, options = {}")
    end

    it "skips ApplicationJob in source parsing" do
      jobs = introspector.send(:extract_jobs_from_source)
      names = jobs.map { |j| j[:name] }
      expect(names).not_to include("ApplicationJob")
    end
  end
end
