require "test_helper"
require_relative "support/with_clues"
require "warden/test/helpers"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include TestSupport::WithClues

  driven_by :rack_test
end

class BrowserSystemTestCase < ApplicationSystemTestCase
  include Warden::Test::Helpers

  driven_by :selenium, using: ENV.fetch("DRIVER", "headless_chrome").presence&.to_sym || :headless_chrome, screen_size: [ 1400, 1400 ]

  setup do
    Warden.test_mode!
    resize_window_to_desktop
  end

  teardown do
    Warden.test_reset!
  end

  private

  def sign_in_as(user)
    login_as(user, scope: :user)
  end

  def resize_window_to_desktop
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end
end
