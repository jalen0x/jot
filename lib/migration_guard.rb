# frozen_string_literal: true

require "open3"
require "pathname"

class MigrationGuard
  MIGRATION_GLOB = "db/migrate/**/*.rb"
  MIGRATION_FILENAME = /\A(?<version>\d{14})_[a-z0-9_]+(?:\.[a-z0-9_]+)?\.rb\z/

  Migration = Data.define(:path, :version)

  def initialize(root: Dir.pwd, base_ref: ENV["MIGRATION_GUARD_BASE_REF"])
    @root = Pathname.new(root)
    @base_ref = base_ref.to_s.strip
  end

  def errors
    migrations, invalid_paths = parse_migrations(current_migration_paths)
    errors = invalid_paths.map { |path| illegal_filename_message(path) }

    errors.concat(duplicate_version_errors(migrations))
    errors.concat(out_of_order_errors(migrations)) unless @base_ref.empty?
    errors
  end

  private

  def current_migration_paths
    Dir.glob(@root.join(MIGRATION_GLOB)).map do |path|
      Pathname.new(path).relative_path_from(@root).to_s
    end.sort
  end

  def base_migration_paths
    stdout, stderr, status = Open3.capture3("git", "ls-tree", "-r", "--name-only", @base_ref, "--", "db/migrate", chdir: @root.to_s)
    return [ stdout.lines.map(&:strip).grep(/\.rb\z/), nil ] if status.success?

    [ [], "Could not read target branch migrations from #{@base_ref}: #{stderr.strip}" ]
  end

  def parse_migrations(paths)
    migrations = []
    invalid_paths = []

    paths.each do |path|
      match = File.basename(path).match(MIGRATION_FILENAME)
      if match
        migrations << Migration.new(path: path, version: match[:version])
      else
        invalid_paths << path
      end
    end

    [ migrations, invalid_paths ]
  end

  def illegal_filename_message(path)
    "Illegal migration filename: #{path}. Use YYYYMMDDHHMMSS_snake_case.rb with an optional engine suffix like .pay.rb."
  end

  def duplicate_version_errors(migrations)
    migrations.group_by(&:version).filter_map do |version, matches|
      next if matches.one?

      "Duplicate migration version #{version}: #{matches.map(&:path).join(', ')}"
    end
  end

  def out_of_order_errors(migrations)
    base_file_paths, git_error = base_migration_paths
    return [ git_error ] if git_error

    base_migrations, invalid_base_paths = parse_migrations(base_file_paths)
    return invalid_base_paths.map { |path| illegal_filename_message(path) } if invalid_base_paths.any?

    base_paths = base_migrations.map(&:path)
    base_max = base_migrations.map(&:version).max
    return [] unless base_max

    migrations.reject { |migration| base_paths.include?(migration.path) }.filter_map do |migration|
      next if migration.version > base_max

      "New migration #{migration.path} must be newer than target branch max #{base_max}."
    end
  end
end
