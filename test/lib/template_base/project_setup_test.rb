require "test_helper"
require "tmpdir"

class TemplateBase::ProjectSetupTest < ActiveSupport::TestCase
  test "renders configuration files and seeds overrides" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(File.join(dir, "config", "application.rb"), "module JalenRailsTemplate\nend\n")
      File.write(File.join(dir, "Dockerfile"), "# docker build -t jalen_rails_template .\n")

      setup = TemplateBase::ProjectSetup.new(
        root: dir,
        project_slug: "starter_app",
        application_name: "Starter App",
        domain: "app.example.test",
        support_email: "support@app.example.test",
        default_from_email: "Starter App <no-reply@app.example.test>",
        web_ip: "10.0.0.2"
      )

      setup.run

      assert_includes File.read(File.join(dir, "config", "database.yml")), "starter_app_development"
      assert_includes File.read(File.join(dir, "config", "deploy.yml")), "host: app.example.test"
      assert_includes File.read(File.join(dir, "config", "template_base.rb")), '"application_name" => "Starter App"'
      assert_includes File.read(File.join(dir, "config", "application.rb")), "module StarterApp"
      assert_includes File.read(File.join(dir, "Dockerfile")), "docker build -t starter_app ."
      assert File.exist?(File.join(dir, "app", "views", "layouts", "application.html.erb"))
      assert_not File.exist?(File.join(dir, "app", "views", "home", "show.html.erb"))
    end
  end
end
