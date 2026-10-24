# Tasarım sistemi vitrini (/design). Route yalnızca Rails.env.local? iken tanımlı; ek güvenlik olarak burada da kontrol.
class DesignController < ApplicationController
  before_action { head :not_found unless Rails.env.local? }

  TOKENS = {
    "Zeminler" => %w[--sa-bg --sa-surface --sa-surface-muted --sa-border],
    "Metin" => %w[--sa-ink --sa-ink-muted --sa-ink-subtle --sa-ink-faint],
    "Vurgu" => %w[--sa-accent --sa-accent-strong --sa-accent-soft --sa-accent-ink --sa-deep],
    "Severity" => %w[--sa-sev-critical --sa-sev-critical-soft --sa-sev-critical-ink
                     --sa-sev-major --sa-sev-major-soft --sa-sev-major-ink
                     --sa-sev-minor --sa-sev-minor-soft --sa-sev-minor-ink],
    "Durum" => %w[--sa-ok --sa-ok-soft --sa-ok-ink --sa-info --sa-info-soft --sa-info-ink]
  }.freeze

  def show
    @tokens = TOKENS
  end
end
