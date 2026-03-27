# frozen_string_literal: true

require "spec_helper"

# Ensure test app models are loaded
require_relative "../../../internal/app/models/application_record"
require_relative "../../../internal/app/models/user"
require_relative "../../../internal/app/models/post"

RSpec.describe RailsAiContext::Introspectors::ModelIntrospector do
  let(:introspector) { described_class.new(Rails.application) }

  describe "#call" do
    subject(:result) { introspector.call }

    it "discovers User and Post models" do
      expect(result).to have_key("User")
      expect(result).to have_key("Post")
    end

    it "extracts User associations" do
      assocs = result["User"][:associations]
      expect(assocs).to include(a_hash_including(name: "posts", type: "has_many"))
    end

    it "extracts Post associations" do
      assocs = result["Post"][:associations]
      expect(assocs).to include(a_hash_including(name: "user", type: "belongs_to"))
    end

    it "extracts validations" do
      vals = result["User"][:validations]
      expect(vals).to include(a_hash_including(kind: "presence", attributes: [ "email" ]))
    end

    it "extracts scopes from source files" do
      user_scope_names = result["User"][:scopes].map { |s| s.is_a?(Hash) ? s[:name] : s }
      post_scope_names = result["Post"][:scopes].map { |s| s.is_a?(Hash) ? s[:name] : s }
      expect(user_scope_names).to include("active", "admins")
      expect(post_scope_names).to include("published", "recent")
    end

    it "extracts enums with values" do
      expect(result["User"][:enums]).to have_key("role")
      expect(result["User"][:enums]["role"]).to be_a(Hash)
      expect(result["User"][:enums]["role"].keys).to contain_exactly("member", "admin")
    end

    it "extracts table names" do
      expect(result["User"][:table_name]).to eq("users")
      expect(result["Post"][:table_name]).to eq("posts")
    end

    it "extracts concerns as array" do
      expect(result["User"][:concerns]).to be_an(Array)
    end

    it "extracts class_methods as array" do
      expect(result["User"][:class_methods]).to be_an(Array)
    end

    it "extracts instance_methods as array" do
      expect(result["User"][:instance_methods]).to be_an(Array)
    end
  end

  describe "#extract_source_macros (private)" do
    let(:fixture_model) { File.join(Rails.root, "app/models/employee.rb") }
    let(:fake_model) { double(name: "Employee") }

    after { FileUtils.rm_f(fixture_model) }

    context "with all supported macros" do
      before do
        File.write(fixture_model, <<~RUBY)
          class Employee < ApplicationRecord
            has_secure_password
            encrypts :ssn, :secret_code
            normalizes :email, :name, with: ->(val) { val.strip.downcase }
            has_one_attached :avatar
            has_many_attached :documents
            has_rich_text :bio
            broadcasts_to :company
            generates_token_for :email_verification
            serialize :preferences
            store :settings, accessors: [:theme, :language]
            delegate :company_name, to: :company
            delegate_missing_to :profile
          end
        RUBY
      end

      subject(:macros) { introspector.send(:extract_source_macros, fake_model) }

      it "detects has_secure_password" do
        expect(macros[:has_secure_password]).to be true
      end

      it "detects encrypts with multiple attributes" do
        expect(macros[:encrypts]).to contain_exactly("ssn", "secret_code")
      end

      it "detects normalizes with multiple attributes" do
        expect(macros[:normalizes]).to contain_exactly("email", "name")
      end

      it "detects has_one_attached" do
        expect(macros[:has_one_attached]).to eq([ "avatar" ])
      end

      it "detects has_many_attached" do
        expect(macros[:has_many_attached]).to eq([ "documents" ])
      end

      it "detects has_rich_text" do
        expect(macros[:has_rich_text]).to eq([ "bio" ])
      end

      it "detects broadcasts" do
        expect(macros[:broadcasts]).to include("broadcasts_to")
      end

      it "detects generates_token_for" do
        expect(macros[:generates_token_for]).to eq([ "email_verification" ])
      end

      it "detects serialize" do
        expect(macros[:serialize]).to eq([ "preferences" ])
      end

      it "detects store" do
        expect(macros[:store]).to eq([ "settings" ])
      end

      it "detects delegate with target" do
        expect(macros[:delegations]).to be_an(Array)
        delegation = macros[:delegations].find { |d| d[:to] == "company" }
        expect(delegation).not_to be_nil
        expect(delegation[:methods]).to include("company_name")
      end

      it "detects delegate_missing_to" do
        expect(macros[:delegate_missing_to]).to eq("profile")
      end
    end

    context "with single-attribute macros" do
      before do
        File.write(fixture_model, <<~RUBY)
          class Employee < ApplicationRecord
            normalizes :email, with: ->(e) { e.strip }
            encrypts :ssn
          end
        RUBY
      end

      subject(:macros) { introspector.send(:extract_source_macros, fake_model) }

      it "handles single normalizes attribute" do
        expect(macros[:normalizes]).to eq([ "email" ])
      end

      it "handles single encrypts attribute" do
        expect(macros[:encrypts]).to eq([ "ssn" ])
      end
    end

    context "with no macros" do
      before do
        File.write(fixture_model, <<~RUBY)
          class Employee < ApplicationRecord
          end
        RUBY
      end

      subject(:macros) { introspector.send(:extract_source_macros, fake_model) }

      it "returns empty hash" do
        expect(macros).to eq({})
      end
    end

    context "when source file does not exist" do
      subject(:macros) { introspector.send(:extract_source_macros, fake_model) }

      it "returns empty hash" do
        expect(macros).to eq({})
      end
    end
  end

  describe "#extract_detailed_macros (private)" do
    let(:fixture_model) { File.join(Rails.root, "app/models/employee.rb") }
    let(:fake_model) { double(name: "Employee") }

    after { FileUtils.rm_f(fixture_model) }

    context "with encryption_details" do
      before do
        File.write(fixture_model, <<~RUBY)
          class Employee < ApplicationRecord
            encrypts :ssn, deterministic: true, downcase: true
            encrypts :secret_code
          end
        RUBY
      end

      subject(:macros) { introspector.send(:extract_detailed_macros, fake_model) }

      it "extracts field name and options for encrypted attributes" do
        expect(macros[:encryption_details]).to be_an(Array)
        ssn_entry = macros[:encryption_details].find { |e| e[:field] == "ssn" }
        expect(ssn_entry).not_to be_nil
        expect(ssn_entry[:options][:deterministic]).to be true
        expect(ssn_entry[:options][:downcase]).to be true
      end

      it "extracts encrypted attributes without options" do
        secret = macros[:encryption_details].find { |e| e[:field] == "secret_code" }
        expect(secret).not_to be_nil
      end
    end

    context "with normalizes_details" do
      before do
        File.write(fixture_model, <<~RUBY)
          class Employee < ApplicationRecord
            normalizes :email, with: ->(e) { e.strip.downcase }
            normalizes :phone, with: ->(p) { p.gsub(/\\D/, "") }
          end
        RUBY
      end

      subject(:macros) { introspector.send(:extract_detailed_macros, fake_model) }

      it "extracts field name and transformation" do
        expect(macros[:normalizes_details]).to be_an(Array)
        email_entry = macros[:normalizes_details].find { |e| e[:field] == "email" }
        expect(email_entry).not_to be_nil
        expect(email_entry[:transformation]).to include("strip.downcase")
      end
    end

    context "with token_generation" do
      before do
        File.write(fixture_model, <<~RUBY)
          class Employee < ApplicationRecord
            generates_token_for :email_verification, expires_in: 2.hours
            generates_token_for :password_reset
          end
        RUBY
      end

      subject(:macros) { introspector.send(:extract_detailed_macros, fake_model) }

      it "extracts purpose and expiry" do
        expect(macros[:token_generation]).to be_an(Array)
        email_token = macros[:token_generation].find { |t| t[:purpose] == "email_verification" }
        expect(email_token).not_to be_nil
        expect(email_token[:expires_in]).to eq("2.hours")
      end

      it "handles token generation without expires_in" do
        pw_token = macros[:token_generation].find { |t| t[:purpose] == "password_reset" }
        expect(pw_token).not_to be_nil
        expect(pw_token).not_to have_key(:expires_in)
      end
    end

    context "when source file does not exist" do
      subject(:macros) { introspector.send(:extract_detailed_macros, fake_model) }

      it "returns empty hash" do
        expect(macros).to eq({})
      end
    end
  end
end
