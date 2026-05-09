require "erb"
require "fileutils"

module TemplateBase
  class ProjectSetup
    attr_reader :root, :template_root, :project_slug, :application_name, :domain,
      :support_email, :default_from_email, :web_ip

    def initialize(root:, project_slug:, application_name:, domain:, support_email:, default_from_email:, web_ip:, template_root: Rails.root.join("lib", "templates"))
      @root = Pathname(root)
      @template_root = Pathname(template_root)
      @project_slug = sanitize_slug(project_slug)
      @application_name = application_name.strip
      @domain = domain.strip
      @support_email = support_email.strip
      @default_from_email = default_from_email.strip
      @web_ip = web_ip.presence
    end

    def run
      render_template("database.yml.tt", root.join("config", "database.yml"))
      render_template("deploy.yml.tt", root.join("config", "deploy.yml"))
      render_template("template_base.rb.tt", root.join("config", "template_base.rb"))
      rewrite_application_module
      rewrite_dockerfile_image
      seed_override("app/views/layouts/application.html.erb")
    end

  private

    def db_prefix
      project_slug
    end

    def module_name
      project_slug.split("_").map(&:capitalize).join
    end

    def rewrite_application_module
      path = root.join("config", "application.rb")
      return unless path.exist?

      content = path.read
      updated = content.sub(/^module [A-Z]\w*$/, "module #{module_name}")
      path.write(updated) if updated != content
    end

    def rewrite_dockerfile_image
      path = root.join("Dockerfile")
      return unless path.exist?

      content = path.read
      updated = content.gsub("jalen_rails_template", project_slug)
      path.write(updated) if updated != content
    end

    def sanitize_slug(value)
      slug = value.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/^_+|_+$/, "")
      raise ArgumentError, "Project slug must contain at least one alphanumeric character" if slug.empty?

      slug
    end

    def render_template(template_name, destination)
      template = template_root.join(template_name)
      raise ArgumentError, "Missing template: #{template}" unless template.exist?

      destination.dirname.mkpath
      result = ERB.new(template.read, trim_mode: "-").result(binding)
      destination.write(result)
    end

    def seed_override(relative_path)
      destination = root.join(relative_path)
      return if destination.exist?

      source = TemplateBase::ROOT.join(relative_path)
      raise ArgumentError, "Missing override seed: #{source}" unless source.exist?

      destination.dirname.mkpath
      FileUtils.cp(source, destination)
    end
  end
end
