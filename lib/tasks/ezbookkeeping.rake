require "ezbookkeeping/source_inventory"

namespace :ezbookkeeping do
  desc "Print source project inventory for the Rails rewrite"
  task :source_inventory do
    source_root = ENV.fetch("EZBOOKKEEPING_SOURCE_ROOT", "/Users/Jalen/code/ezbookkeeping")
    inventory = Ezbookkeeping::SourceInventory.new(source_root)

    puts "Models: #{inventory.models.count}"
    inventory.models.each { |model| puts "  #{model}" }

    puts "API endpoints: #{inventory.api_endpoints.count}"
    inventory.api_endpoints.each { |endpoint| puts "  #{endpoint}" }

    puts "Desktop routes: #{inventory.desktop_routes.count}"
    inventory.desktop_routes.each { |route| puts "  #{route}" }

    puts "Mobile routes: #{inventory.mobile_routes.count}"
    inventory.mobile_routes.each { |route| puts "  #{route}" }
  end
end
