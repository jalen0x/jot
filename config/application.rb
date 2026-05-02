require_relative "boot"

require "rails/all"
require_relative "../lib/template_base"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Jot
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1
    config.active_record.schema_format = :sql

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets generators tasks template_base templates])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Exclude JavaScript assets directory from Rails asset pipeline (handled by esbuild)
    config.assets.excluded_paths << Rails.root.join("app/assets/javascripts")

    # ViewComponent previews (rendered via Lookbook at /lookbook in development)
    config.view_component.preview_paths = [ Rails.root.join("test/components/previews").to_s ]

    # Prefer app/ over the internal template base so downstream overrides win.
    config.railties_order = [ :main_app, TemplateBase::Engine, :all ]
  end
end
