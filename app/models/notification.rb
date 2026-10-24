class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :alert, optional: true    # on-call bildirimi
  belongs_to :incident, optional: true # response hatırlatıcısı (Z3/Z4)

  scope :unread, -> { where(read_at: nil) }

  # Boşluk raporu gibi bir alarm/olaya bağlı olmayan bildirimde metin zorunlu.
  validates :message, presence: true, unless: -> { alert || incident }
end
