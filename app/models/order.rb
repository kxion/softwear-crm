class Order < ActiveRecord::Base
  include TrackingHelpers

  acts_as_paranoid

  searchable do
    text :name, :email, :firstname, :lastname, :company, :twitter, :terms, :delivery_method
    text :jobs do
      jobs.map { |j| "#{j.name} #{j.description}" }
    end
    # TODO: refactor
    [:firstname, :lastname, :email, :terms, :delivery_method, :company, :phone_number].each do |field|
      string field
    end

    double :total
    double :commission_amount

    date :in_hand_by

    reference :salesperson
  end

  tracked by_current_user

  VALID_PAYMENT_TERMS = [
    '',
    'Paid in full on purchase',
    'Half down on purchase',
    'Paid in full on pick up',
    'Net 30',
    'Net 60'
  ]

  VALID_DELIVERY_METHODS = [
    'Pick up in Ann Arbor',
    'Pick up in Ypsilanti',
    'Ship to one location',
    'Ship to multiple locations'
  ]

  #TODO: custom validators for phone and email??
  #TODO: shouldn't validate salesperson_id, but rather salesperson?? could make relation like artwork_request?
  validates :delivery_method, presence: true
  validates :email, presence: true, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i }
  validates :firstname, presence: true
  validates :lastname, presence: true
  validates :name, presence: true
  validates :phone_number, format: { with: /\d{3}-\d{3}-\d{4}/, message: 'is incorrectly formatted, use 000-000-0000' }
  validates :salesperson_id, presence: true
  validates :store, presence: true
  validates :tax_id_number, presence: true, if: :tax_exempt?
  validates :terms, presence: true
  #TODO: can this be sexified?
  validates_inclusion_of(:delivery_method,
      in: VALID_DELIVERY_METHODS,
      message: 'Invalid delivery method')

  belongs_to :store
  belongs_to :user, :foreign_key => :salesperson_id
  has_many :artwork_requests, through: :jobs
  has_many :jobs
  has_many :payments
  has_many :proofs
  accepts_nested_attributes_for :payments

  # TODO: refactor this out to concern
  def all_activities
    PublicActivity::Activity.where( '
      (
        activities.recipient_type = ? AND activities.recipient_id = ?
      ) OR
      (
        activities.trackable_type = ? AND activities.trackable_id = ?
      )
    ', *([self.class.name, self.id] * 2) ).order('created_at DESC')
  end

  def balance
    total - payment_total
  end

  def line_items
    LineItem.where(line_itemable_id: job_ids, line_itemable_type: 'Job')
  end

  def payment_status
    if balance <= 0
      'Payment Complete'
    else
      case terms
      when 'Paid in full on purchase'
          'Awaiting Payment'
      when 'Half down on purchase'
        balance >= (total * 0.49) ? 'Awaiting Payment' : 'Payment Terms Met'
      when 'Paid in full on pick up'
        Time.now >= self.in_hand_by ? 'Awaiting Payment' : 'Payment Terms Met'
      when 'Net 30'
        Time.now >= (self.in_hand_by + 30.days) ? 'Awaiting Payment' : 'Payment Terms Met'
      when 'Net 60'
        Time.now >= (self.in_hand_by + 60.days) ? 'Awaiting Payment' : 'Payment Terms Met'
      else 'Payment Terms Pending'
      end
    end
  end

  def payment_total
    total = 0
    # TODO: make fancy, use select
    self.payments.each do |payment|
      unless payment.nil? || payment.is_refunded?
        total += payment.amount
      end
    end
    total
  end

  def percent_paid
    payment_total / total * 100
  end

  def salesperson
    User.find(salesperson_id)
  end

  def salesperson_name
    User.find(salesperson_id).full_name
  end

  def subtotal
    line_items.map(&:total_price).reduce(0, :+)
  end

  def tax
    0.6
  end

  def total
    subtotal + subtotal * tax
  end
end
