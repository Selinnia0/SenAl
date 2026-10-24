class PasswordsController < ApplicationController
  layout "auth"
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: "Çok fazla deneme. Biraz sonra tekrar deneyin." }

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path, notice: "Bu e-posta adresine ait bir kullanıcı varsa şifre sıfırlama talimatları gönderildi."
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "Şifreniz sıfırlandı."
    else
      redirect_to edit_password_path(params[:token]), alert: "Şifreler eşleşmedi."
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "Şifre sıfırlama bağlantısı geçersiz veya süresi dolmuş."
    end
end
