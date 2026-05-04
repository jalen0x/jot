class InsightExplorer < ApplicationRecord
  include Discard::Model

  CONFIG_MAX_BYTES = 32.kilobytes

  has_prefix_id :ixp

  belongs_to :user

  normalizes :name, with: ->(name) { name.to_s.strip }

  validates :name, presence: true, length: { maximum: 64 }
  validates :display_order, numericality: { only_integer: true }
  validate :config_must_be_object
  validate :config_size

  def as_json(_options = {})
    {
      id: to_param,
      name: name,
      display_order: display_order,
      hidden: hidden,
      config: config
    }
  end

  private

  def config_must_be_object
    errors.add(:config, "must be a JSON object") unless config.is_a?(Hash)
  end

  def config_size
    return unless config.is_a?(Hash)

    errors.add(:config, "is too large") if JSON.generate(config).bytesize > CONFIG_MAX_BYTES
  end
end
