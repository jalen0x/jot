require "pathname"

module Ezbookkeeping
  class SourceInventory
    API_ROUTE_PATTERN = /api(?:V1)?Route\.(GET|POST)\("([^"]+)"/
    MODEL_PATTERN = /SyncStructs\(new\(models\.(\w+)\)\)/
    ROUTE_PATTERN = /path:\s*'([^']+)'/

    def initialize(source_root)
      @source_root = Pathname(source_root)
    end

    def models
      scan(database_file, MODEL_PATTERN).sort
    end

    def api_endpoints
      read_file(webserver_file).scan(API_ROUTE_PATTERN).map { |method, path| "#{method} #{path}" }
    end

    def desktop_routes
      scan(desktop_routes_file, ROUTE_PATTERN)
    end

    def mobile_routes
      scan(mobile_routes_file, ROUTE_PATTERN)
    end

    private

    attr_reader :source_root

    def database_file = source_root.join("cmd/database.go")
    def webserver_file = source_root.join("cmd/webserver.go")
    def desktop_routes_file = source_root.join("src/router/desktop.ts")
    def mobile_routes_file = source_root.join("src/router/mobile.ts")

    def scan(path, pattern)
      read_file(path).scan(pattern).flatten
    end

    def read_file(path)
      File.read(path)
    end
  end
end
