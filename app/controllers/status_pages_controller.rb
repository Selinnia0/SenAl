# Halka açık durum sayfası (/status). Giriş gerektirmez; yalnızca public_impact olaylar ve yayınlanmış mesajlar.
class StatusPagesController < ApplicationController
  allow_unauthenticated_access
  layout "public"

  def show
    @status_page = StatusPage.new
  end
end
