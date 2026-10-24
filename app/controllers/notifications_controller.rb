class NotificationsController < ApplicationController
  def index
    @notifications = Current.user.notifications.unread.includes(:alert, :incident).order(created_at: :desc)
  end

  def read
    Current.user.notifications.find(params[:id]).update!(read_at: Time.current)
    redirect_to notifications_path, status: :see_other
  end

  def read_all
    Current.user.notifications.unread.update_all(read_at: Time.current)
    redirect_to notifications_path, notice: "Tüm bildirimler okundu olarak işaretlendi.", status: :see_other
  end
end
