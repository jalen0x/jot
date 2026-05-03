require "test_helper"

class TransactionTemplateTaggingTest < ActiveSupport::TestCase
  test "connects a transaction template to a tag" do
    user = create(:user)
    template = create_template(user: user)
    tag = TransactionTag.create!(user: user, name: "Work", display_order: 1)

    TransactionTemplateTagging.create!(user: user, transaction_template: template, transaction_tag: tag)

    assert_equal [ tag ], template.transaction_tags.to_a
    assert_equal [ template ], tag.transaction_templates.to_a
  end

  private

  def create_template(user:)
    account = Account.create!(
      user: user,
      name: "Cash",
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: 0,
      display_order: 1
    )
    category = TransactionCategory.create!(
      user: user,
      name: "Food",
      category_type: :expense,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )

    TransactionTemplate.create!(
      user: user,
      account: account,
      transaction_category: category,
      template_kind: :normal,
      transaction_kind: :expense,
      name: "Lunch",
      source_amount_cents: 1_200,
      destination_amount_cents: 0,
      display_order: 1
    )
  end
end
