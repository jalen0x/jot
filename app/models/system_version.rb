class SystemVersion
  def self.current
    new(
      version: ENV.fetch("APP_VERSION", "development"),
      commit_hash: ENV["APP_COMMIT_HASH"],
      build_time: ENV["APP_BUILD_TIME"]
    )
  end

  attr_reader :version, :commit_hash, :build_time

  def initialize(version:, commit_hash:, build_time:)
    @version = version
    @commit_hash = commit_hash
    @build_time = build_time
  end

  def as_json(_options = {})
    {
      version: version,
      commit_hash: commit_hash,
      build_time: build_time
    }.compact
  end
end
