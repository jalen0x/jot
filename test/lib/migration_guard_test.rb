require "test_helper"
require "tmpdir"
require_relative "../../lib/migration_guard"

class MigrationGuardTest < ActiveSupport::TestCase
  test "rejects new migrations older than the target branch maximum" do
    in_git_repo do |root|
      write_migration(root, "20250101000000_create_users.rb")
      git(root, "add", ".")
      git(root, "commit", "-m", "base")

      write_migration(root, "20240101000000_add_profiles.rb")

      errors = MigrationGuard.new(root: root, base_ref: "HEAD").errors

      assert_includes errors.join("\n"), "must be newer than target branch max 20250101000000"
    end
  end

  test "rejects duplicate migration versions" do
    Dir.mktmpdir do |root|
      write_migration(root, "20250101000000_create_users.rb")
      write_migration(root, "20250101000000_create_accounts.pay.rb")

      errors = MigrationGuard.new(root: root).errors

      assert_includes errors.join("\n"), "Duplicate migration version 20250101000000"
    end
  end

  test "rejects illegal migration filenames" do
    Dir.mktmpdir do |root|
      write_migration(root, "20250101000000_AddUsers.rb")

      errors = MigrationGuard.new(root: root).errors

      assert_includes errors.join("\n"), "Illegal migration filename"
    end
  end

  private

  def in_git_repo
    Dir.mktmpdir do |root|
      git(root, "init", "--initial-branch=main")
      git(root, "config", "user.email", "test@example.com")
      git(root, "config", "user.name", "Test User")
      yield root
    end
  end

  def write_migration(root, filename)
    path = File.join(root, "db/migrate", filename)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "class TestMigration < ActiveRecord::Migration[8.0]\nend\n")
  end

  def git(root, *args)
    system("git", *args, chdir: root, out: File::NULL, err: File::NULL)
  end
end
