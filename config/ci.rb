# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"
  step "Setup idempotency", "bin/setup --skip-server"

  step "Migrations: Guard", "bin/check_migrations"
  step "Migrations: Schema is current", "env RAILS_ENV=test bin/rails db:migrate && git diff --exit-code db/structure.sql"

  step "Style: Ruby", "bin/rubocop"
  step "Style: ERB", "bundle exec erb_lint --lint-all"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Check: Zeitwerk", "bin/rails zeitwerk:check"
  step "Tests: Rails", "bin/rails test"
  step "Tests: System", "bin/rails test:system"

  # Set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  has_signoff = system("which gh > /dev/null 2>&1") && system("gh extension list 2>/dev/null | grep -q signoff")

  if success? && has_signoff
    step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  elsif success?
    puts "\n⚠️  Skipping signoff — install with: gh extension install basecamp/gh-signoff"
  else
    failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  end
end
