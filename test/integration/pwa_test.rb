require "test_helper"

class PwaTest < ActionDispatch::IntegrationTest
  test "serves the web app manifest" do
    get pwa_manifest_path(format: :json)

    assert_response :success
    manifest = JSON.parse(response.body)
    assert_equal TemplateBase.config.application_name, manifest.fetch("name")
    assert_equal "/", manifest.fetch("start_url")
    assert_equal "standalone", manifest.fetch("display")
    assert_equal "/", manifest.fetch("scope")
  end

  test "serves the service worker" do
    get pwa_service_worker_path(format: :js)

    assert_response :success
    assert_match(/service worker/i, response.body)
  end

  test "links the manifest from the application layout" do
    get root_path

    assert_response :success
    assert_includes response.body, %(rel="manifest")
    assert_includes response.body, pwa_manifest_path(format: :json)
  end
end
