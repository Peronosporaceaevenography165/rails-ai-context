# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Fingerprinter do
  describe ".compute" do
    it "returns a hex digest string" do
      result = described_class.compute(Rails.application)
      expect(result).to match(/\A[a-f0-9]{64}\z/)
    end

    it "returns the same value on repeated calls with no changes" do
      a = described_class.compute(Rails.application)
      b = described_class.compute(Rails.application)
      expect(a).to eq(b)
    end

    it "detects changes to .rake files" do
      before = described_class.compute(Rails.application)
      rake_file = File.join(Rails.root, "lib/tasks/example.rake")
      original_mtime = File.mtime(rake_file)

      # Touch the file to change mtime
      FileUtils.touch(rake_file)
      after = described_class.compute(Rails.application)

      # Restore original mtime
      File.utime(original_mtime, original_mtime, rake_file)

      expect(before).not_to eq(after)
    end

    it "detects changes to .erb view files" do
      before = described_class.compute(Rails.application)
      erb_file = File.join(Rails.root, "app/views/posts/index.html.erb")
      original_mtime = File.mtime(erb_file)

      FileUtils.touch(erb_file)
      after = described_class.compute(Rails.application)

      File.utime(original_mtime, original_mtime, erb_file)

      expect(before).not_to eq(after)
    end

    it "detects changes to .js stimulus controllers" do
      # Use permanent hello_controller.js fixture
      js_file = File.join(Rails.root, "app/javascript/controllers/hello_controller.js")
      original_mtime = File.mtime(js_file)

      before = described_class.compute(Rails.application)
      FileUtils.touch(js_file)
      after = described_class.compute(Rails.application)

      File.utime(original_mtime, original_mtime, js_file)

      expect(before).not_to eq(after)
    end
  end

  describe ".changed?" do
    it "returns false when fingerprint matches" do
      current = described_class.compute(Rails.application)
      expect(described_class.changed?(Rails.application, current)).to be false
    end

    it "returns true when fingerprint differs" do
      expect(described_class.changed?(Rails.application, "stale")).to be true
    end
  end
end
