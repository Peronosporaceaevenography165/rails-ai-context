# frozen_string_literal: true

module RailsAiContext
  module Introspectors
    # Analyzes Gemfile.lock to identify installed gems and
    # map them to known patterns/frameworks the AI should know about.
    class GemIntrospector
      attr_reader :app

      # Known gems that significantly affect how the app works.
      # The AI needs to know about these to give accurate advice.
      NOTABLE_GEMS = {
        # Auth
        "devise"          => { category: :auth, note: "Authentication via Devise. Check User model for devise modules." },
        "omniauth"        => { category: :auth, note: "OAuth integration via OmniAuth." },
        "pundit"          => { category: :auth, note: "Authorization via Pundit policies in app/policies/." },
        "cancancan"       => { category: :auth, note: "Authorization via CanCanCan abilities." },
        "rodauth-rails"   => { category: :auth, note: "Authentication via Rodauth." },

        # Background jobs
        "sidekiq"         => { category: :jobs, note: "Background jobs via Sidekiq. Check config/sidekiq.yml." },
        "good_job"        => { category: :jobs, note: "Background jobs via GoodJob (Postgres-backed)." },
        "solid_queue"     => { category: :jobs, note: "Background jobs via SolidQueue (Rails 8 default)." },
        "delayed_job"     => { category: :jobs, note: "Background jobs via DelayedJob." },

        # Frontend
        "turbo-rails"     => { category: :frontend, note: "Hotwire Turbo for SPA-like navigation. Check Turbo Streams and Frames." },
        "stimulus-rails"  => { category: :frontend, note: "Stimulus.js controllers in app/javascript/controllers/." },
        "importmap-rails" => { category: :frontend, note: "Import maps for JS (no bundler). Check config/importmap.rb." },
        "jsbundling-rails" => { category: :frontend, note: "JS bundling (esbuild/webpack/rollup). Check package.json." },
        "cssbundling-rails" => { category: :frontend, note: "CSS bundling. Check package.json for Tailwind/PostCSS/etc." },
        "tailwindcss-rails" => { category: :frontend, note: "Tailwind CSS integration." },
        "react-rails"     => { category: :frontend, note: "React components in Rails views." },
        "inertia_rails"   => { category: :frontend, note: "Inertia.js for SPA with Rails backend." },

        # API
        "grape"           => { category: :api, note: "API framework via Grape. Check app/api/." },
        "graphql"         => { category: :api, note: "GraphQL API. Check app/graphql/ for types and mutations." },
        "jsonapi-serializer" => { category: :api, note: "JSON:API serialization." },
        "jbuilder"        => { category: :api, note: "JSON views via Jbuilder templates." },

        # Database
        "pg"              => { category: :database, note: "PostgreSQL adapter." },
        "mysql2"          => { category: :database, note: "MySQL adapter." },
        "sqlite3"         => { category: :database, note: "SQLite adapter." },
        "redis"           => { category: :database, note: "Redis client. Used for caching/sessions/Action Cable." },
        "solid_cache"     => { category: :database, note: "Database-backed cache (Rails 8)." },
        "solid_cable"     => { category: :database, note: "Database-backed Action Cable (Rails 8)." },

        # File handling
        "activestorage"   => { category: :files, note: "Active Storage for file uploads." },
        "shrine"          => { category: :files, note: "File uploads via Shrine." },
        "carrierwave"     => { category: :files, note: "File uploads via CarrierWave." },

        # Testing
        "rspec-rails"     => { category: :testing, note: "RSpec test framework. Tests in spec/." },
        "minitest"        => { category: :testing, note: "Minitest framework. Tests in test/." },
        "factory_bot_rails" => { category: :testing, note: "Test fixtures via FactoryBot in spec/factories/." },
        "faker"           => { category: :testing, note: "Fake data generation for tests." },
        "capybara"        => { category: :testing, note: "Integration/system tests with Capybara." },

        # Deployment
        "kamal"           => { category: :deploy, note: "Deployment via Kamal. Check config/deploy.yml." },
        "capistrano"      => { category: :deploy, note: "Deployment via Capistrano. Check config/deploy/." }
      }.freeze

      def initialize(app)
        @app = app
      end

      # @return [Hash] gem analysis
      def call
        lock_path = File.join(app.root, "Gemfile.lock")
        return { error: "No Gemfile.lock found" } unless File.exist?(lock_path)

        specs = parse_lockfile(lock_path)

        {
          total_gems: specs.size,
          ruby_version: specs["ruby"]&.first,
          notable_gems: detect_notable_gems(specs),
          categories: categorize_gems(specs)
        }
      end

      private

      def parse_lockfile(path)
        gems = {}
        in_gems = false

        File.readlines(path).each do |line|
          if line.strip == "GEM"
            in_gems = true
            next
          elsif line.strip.empty? || line.match?(/^\S/)
            in_gems = false if in_gems && line.match?(/^\S/) && !line.strip.start_with?("remote:", "specs:")
          end

          if in_gems && (match = line.match(/^\s{4}(\S+)\s+\((.+)\)/))
            gems[match[1]] = match[2]
          end
        end

        gems
      end

      def detect_notable_gems(specs)
        NOTABLE_GEMS.filter_map do |gem_name, info|
          next unless specs.key?(gem_name)

          {
            name: gem_name,
            version: specs[gem_name],
            category: info[:category].to_s,
            note: info[:note]
          }
        end
      end

      def categorize_gems(specs)
        found = detect_notable_gems(specs)
        found.group_by { |g| g[:category] }
             .transform_values { |gems| gems.map { |g| g[:name] } }
      end
    end
  end
end
