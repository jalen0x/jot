class AddLastOtpAtToTwoFactorAuthentications < ActiveRecord::Migration[8.1]
  def change
    add_column :two_factor_authentications, :last_otp_at, :datetime,
               comment: "Most recent successful OTP timestep; used to prevent replay within the drift window"
  end
end
