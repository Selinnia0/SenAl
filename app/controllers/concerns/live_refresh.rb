# Turbo 8 sayfa yenilemesi yayını (morph). Callback değil: başarılı işlemden sonra controller'da açıkça çağrılır.
# İşlemi yapan tarayıcı kendi isteğinin yenilemesini request_id sayesinde yok sayar.
module LiveRefresh
  private
    def broadcast_refresh(*streamables)
      streamables.each do |streamable|
        Turbo::StreamsChannel.broadcast_refresh_to(streamable, request_id: Turbo.current_request_id)
      end
    end
end
