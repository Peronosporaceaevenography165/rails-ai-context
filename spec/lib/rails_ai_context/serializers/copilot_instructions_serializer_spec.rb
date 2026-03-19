# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Serializers::CopilotInstructionsSerializer do
  let(:context) do
    {
      models: { "User" => { associations: [ { type: "has_many", name: "posts" } ], validations: [] } },
      controllers: { controllers: { "UsersController" => { actions: %w[index show] } } }
    }
  end

  it "generates .github/instructions/*.instructions.md with applyTo" do
    Dir.mktmpdir do |dir|
      result = described_class.new(context).call(dir)
      expect(result[:written].size).to eq(2)

      models_file = File.read(File.join(dir, ".github", "instructions", "rails-models.instructions.md"))
      expect(models_file).to include("applyTo:")
      expect(models_file).to include("app/models/**/*.rb")
      expect(models_file).to include("User")

      ctrl_file = File.read(File.join(dir, ".github", "instructions", "rails-controllers.instructions.md"))
      expect(ctrl_file).to include("applyTo:")
      expect(ctrl_file).to include("app/controllers/**/*.rb")
      expect(ctrl_file).to include("UsersController")
    end
  end

  it "skips models file when no models" do
    context[:models] = {}
    Dir.mktmpdir do |dir|
      result = described_class.new(context).call(dir)
      expect(result[:written].size).to eq(1) # only controllers
    end
  end

  it "skips controllers file when no controllers" do
    context[:controllers] = { controllers: {} }
    Dir.mktmpdir do |dir|
      result = described_class.new(context).call(dir)
      expect(result[:written].size).to eq(1) # only models
    end
  end

  it "skips unchanged files" do
    Dir.mktmpdir do |dir|
      first = described_class.new(context).call(dir)
      second = described_class.new(context).call(dir)
      expect(second[:written]).to be_empty
      expect(second[:skipped].size).to eq(first[:written].size)
    end
  end
end
