require "test_helper"
require "tmpdir"
require "fileutils"

class Ezbookkeeping::SourceInventoryTest < ActiveSupport::TestCase
  test "extracts source models api endpoints and frontend routes" do
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "cmd"))
      FileUtils.mkdir_p(File.join(root, "src/router"))

      File.write(File.join(root, "cmd/database.go"), <<~GO)
        datastore.Container.UserDataStore.SyncStructs(new(models.Account))
        datastore.Container.UserDataStore.SyncStructs(new(models.Transaction))
      GO

      File.write(File.join(root, "cmd/webserver.go"), <<~GO)
        apiV1Route.GET("/accounts/list.json", bindApi(api.Accounts.AccountListHandler))
        apiV1Route.POST("/accounts/add.json", bindApi(api.Accounts.AccountCreateHandler))
      GO

      File.write(File.join(root, "src/router/desktop.ts"), <<~TS)
        { path: '/account/list', component: AccountListPage }
      TS

      File.write(File.join(root, "src/router/mobile.ts"), <<~TS)
        { path: '/account/add', async: asyncResolve(AccountEditPage) }
      TS

      inventory = Ezbookkeeping::SourceInventory.new(root)

      assert_equal [ "Account", "Transaction" ], inventory.models
      assert_equal [ "GET /accounts/list.json", "POST /accounts/add.json" ], inventory.api_endpoints
      assert_equal [ "/account/list" ], inventory.desktop_routes
      assert_equal [ "/account/add" ], inventory.mobile_routes
    end
  end
end
