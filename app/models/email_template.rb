class EmailTemplate < ActiveRecord::Base
  acts_as_paranoid

  TEMPLATE_TYPES = %w(Quote QuoteRequest)

  validates :subject, :body, :name, :template_type, :to, :plaintext_body, :from, presence: true

end
