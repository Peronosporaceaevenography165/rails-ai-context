# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Serializers::ContextFileSerializer do
  let(:context) { RailsAiContext.introspect }

  describe "#call" do
    it "writes files for all formats" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        serializer = described_class.new(context, format: :all)
        result = serializer.call
        expect(result[:written].size).to eq(5)
        expect(result[:skipped]).to be_empty
      end
    end

    it "skips unchanged files on second run" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        described_class.new(context, format: :claude).call
        result = described_class.new(context, format: :claude).call
        expect(result[:skipped].size).to eq(1)
        expect(result[:written]).to be_empty
      end
    end

    it "writes a single format" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        serializer = described_class.new(context, format: :claude)
        result = serializer.call
        expect(result[:written].size).to eq(1)
        expect(File.read(result[:written].first)).to include("Claude Code")
      end
    end

    it "dispatches cursor format to RulesSerializer" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        serializer = described_class.new(context, format: :cursor)
        result = serializer.call
        expect(File.read(result[:written].first)).to include("Project Rules")
      end
    end

    it "raises for unknown format" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        serializer = described_class.new(context, format: :bogus)
        expect { serializer.call }.to raise_error(ArgumentError, /Unknown format/)
      end
    end
  end
end
