namespace :setup do
  desc "Setup project with custom configuration"
  task project: :environment do
    print "Enter project slug (e.g., musicforge): "
    project_slug = STDIN.gets.chomp

    if project_slug.strip.empty?
      puts "Error: Project slug cannot be empty"
      exit 1
    end

    print "Enter application name (e.g., Musicforge): "
    application_name = STDIN.gets.chomp

    if application_name.strip.empty?
      puts "Error: Application name cannot be empty"
      exit 1
    end

    print "Enter canonical host (e.g., app.example.com): "
    domain = STDIN.gets.chomp.strip

    if domain.empty?
      puts "Error: Canonical host cannot be empty"
      exit 1
    end

    print "Enter support email (leave empty for support@#{domain}): "
    support_email = STDIN.gets.chomp.strip
    support_email = "support@#{domain}" if support_email.empty?

    print "Enter default from email (leave empty for #{application_name} <no-reply@#{domain}>): "
    default_from_email = STDIN.gets.chomp.strip
    default_from_email = "#{application_name} <no-reply@#{domain}>" if default_from_email.empty?

    print "Enter web server IP (leave empty to keep current): "
    web_ip = STDIN.gets.chomp.strip
    web_ip = nil if web_ip.empty?

    puts "\nConfiguring project slug: #{project_slug}"
    puts "Application name: #{application_name}"
    puts "Canonical host: #{domain}"
    puts "Support email: #{support_email}"
    puts "Default from email: #{default_from_email}"
    puts "Web server IP: #{web_ip || '(unchanged)'}"
    puts "Database: Kamal `db` accessory on the web server (postgres:18)"
    puts ""

    TemplateBase::ProjectSetup.new(
      root: Rails.root,
      project_slug:,
      application_name:,
      domain:,
      support_email:,
      default_from_email:,
      web_ip:
    ).run

    puts "\n✅ Project setup complete!"
    puts "\nNext steps:"
    puts "1. Run 'bin/setup' to install dependencies and create databases"
    puts "2. Review config/template_base.rb and any seeded overrides in app/views"
    puts "3. Configure your secrets in .kamal/secrets"
    puts "4. Deploy with 'bin/kamal deploy'"
  end
end
