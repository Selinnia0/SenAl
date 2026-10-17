# Her gün 08:00 (Istanbul) çalışır (config/recurring.yml). Yalnızca GapReport.run! çağırır.
class GapReportJob < ApplicationJob
  queue_as :default

  def perform
    GapReport.run!
  end
end
