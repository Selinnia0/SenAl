class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "SenAl şifre sıfırlama", to: user.email_address
  end
end
