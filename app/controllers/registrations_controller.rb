class RegistrationsController < ApplicationController
  layout "auth"
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Çok fazla deneme. Biraz sonra tekrar deneyin." }

  def new
    @user = User.new
  end

  def create
    # role izinli parametrelerde yok: kayıt olan herkes responder olur.
    @user = User.new(registration_params)

    if @user.save
      start_new_session_for @user
      redirect_to dashboard_path, notice: "Hoş geldiniz, #{@user.name}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def registration_params
      params.expect(user: %i[ name email_address academic_role password password_confirmation ])
    end
end
