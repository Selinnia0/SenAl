require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module SenAl
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Istanbul"
    config.i18n.default_locale = :tr
    config.i18n.available_locales = [ :tr, :en ]

    # Demo aracı "Zaman sıçraması" (TimeSkip). Geliştirme/testte açık; production'da yalnızca
    # TIME_SKIP_ENABLED=1 ile açılır.
    config.x.time_skip_enabled = ENV.fetch("TIME_SKIP_ENABLED") { Rails.env.production? ? "0" : "1" } == "1"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
