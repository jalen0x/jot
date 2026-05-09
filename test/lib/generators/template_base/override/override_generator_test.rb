require "test_helper"
require "tmpdir"
require "generators/template_base/override/override_generator"

class TemplateBase::OverrideGeneratorTest < ActiveSupport::TestCase
  test "copies a single file override" do
    Dir.mktmpdir do |dir|
      generator = TemplateBase::OverrideGenerator.new([ "app/views/layouts/application.html.erb" ], {}, destination_root: dir)
      generator.invoke_all

      assert File.exist?(File.join(dir, "app", "views", "layouts", "application.html.erb"))
    end
  end

  test "copies a directory override" do
    Dir.mktmpdir do |dir|
      generator = TemplateBase::OverrideGenerator.new([ "app/views/devise/passwords" ], {}, destination_root: dir)
      generator.invoke_all

      assert File.exist?(File.join(dir, "app", "views", "devise", "passwords", "new.html.erb"))
      assert File.exist?(File.join(dir, "app", "views", "devise", "passwords", "edit.html.erb"))
    end
  end
end
