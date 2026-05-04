module TemplateBase
  class Engine < ::Rails::Engine
    engine_name "template_base"
    config.root = TemplateBase::ROOT

    config.autoload_paths << TemplateBase::ROOT.join("app", "controllers").to_s
    config.autoload_paths << TemplateBase::ROOT.join("app", "services").to_s
    config.eager_load_paths << TemplateBase::ROOT.join("app", "controllers").to_s
    config.eager_load_paths << TemplateBase::ROOT.join("app", "services").to_s

    config.app_generators do |generators|
      generators.templates.unshift File.expand_path("../templates", __dir__)
      generators.scaffold_stylesheet false
    end

    initializer "template_base.view_paths" do
      ActiveSupport.on_load(:action_controller_base) do
        append_view_path TemplateBase::ROOT.join("app", "views")
      end
    end
  end
end
