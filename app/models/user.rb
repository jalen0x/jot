class User < ApplicationRecord
  include Users::Authenticatable, Users::Profile, Users::SoftDelete

  has_many :accounts, dependent: :restrict_with_error
  has_many :transactions, dependent: :restrict_with_error
end
