module ManagerOnly
  extend ActiveSupport::Concern

  included do
    before_action :require_manager
  end

  private
    def require_manager
      redirect_to dashboard_path, alert: "Bu sayfa yalnızca yöneticiler içindir." unless Current.user&.manager?
    end
end
