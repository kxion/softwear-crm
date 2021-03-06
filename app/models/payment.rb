class Payment < ActiveRecord::Base
  include ActionView::Helpers::NumberHelper
  include PublicActivity::Common
  include Softwear::Auth::BelongsToUser

  class PaymentError < StandardError
  end

  searchable do
    integer :payment_method
    integer :store_id
    string :display_payment_method

    boolean :undropped do
      pending_drop
    end

    integer :id
  end

  COUNTRY_NAMES = {
    'US' => 'United States'
  }

  VALID_PAYMENT_METHODS = {
    1 => 'Cash',
    8 => 'Credit Card',
    3 => 'Check',
    4 => 'PayPal',
    5 => 'Trade First',
    6 => 'Trade',
    7 => 'Wire Transfer',
    2 => 'Swiped Credit Card',
    9 => 'Group Payment'
  }

  FIELDS_TO_RENDER_FOR_METHOD = {
    3 => [:check_dl_no, :check_phone_no],
    4 => [:pp_transaction_id],
    5 => [:t_name, :t_company_name, :tf_number],
    6 => [:t_name, :t_company_name, :t_description],
    7 => [:pp_transaction_id],
    8 => [:cc_name, :cc_company, :cc_number, :cc_transaction, :pp_ref, :billing_address],
  }

  CREDIT_CARD_TYPES = {
    amex:                      'American Express',
    diners_club_carte_blanche: 'Diners Club Carte Blanche',
    diners_club_international: 'Diners Club International',
    mastercard:                'MasterCard',
    discover:                  'Discover Card',
    jcb:                       'JCB',
    laser:                     'Laser',
    maestro:                   'Maestro',
    visa:                      'Visa',
    visa_electron:             'Visa electron'
  }

  CREDIT_CARD_GATEWAY = ActiveMerchant::Billing::PayflowGateway
  PAYPAL_GATEWAY = ActiveMerchant::Billing::PaypalExpressGateway

  acts_as_paranoid

  default_scope { order(:created_at) }
  scope :undropped, -> { includes(:payment_drop_payments).where(payment_drop_payments: { payment_id: nil }) }
  scope :dropped, -> { includes(:payment_drop_payments).where.not(payment_drop_payments: { payment_id: nil }) }
  scope :retail, -> { where.not(retail_description: nil) }

  belongs_to :order, touch: true
  belongs_to :store
  belongs_to_user_called :salesperson
  has_many :discounts, as: :discountable # Only refunds
  has_many :payment_drop_payments

  after_validation :purchase!, on: :create
  after_create :calculate_sales_tax_amount
  after_save :recalculate_order_fields
  after_destroy :recalculate_order_fields
  after_initialize -> (p) { p.sales_tax_amount = 0 if p.sales_tax_amount.try(:nan?) }

  validates :store, :payment_method, :amount, :salesperson_id, presence: true
  validates :pp_transaction_id, presence: true, uniqueness: true,
               if: -> p { p.payment_method == 4 || p.payment_method == 7 }
  validates :t_name, :t_company_name, :tf_number, presence: true, if: -> p { p.payment_method == 5 }
  validates :t_name, :t_company_name, :t_description, presence: true, if: -> p { p.payment_method == 6 }
  validates :cc_number, :cc_name, presence: true, if: :credit_card?
  validates :address1, :city, :state, :country, presence: true, if: :credit_card? unless Rails.env.test?
  validate :amount_doesnt_overflow_order_balance
  validate :amount_greater_than_zero
  validate :credit_card_is_valid, if: :credit_card?

  # NOTE These are all transient and only ever exist on the instance of a CC payment being created
  attr_reader :actual_cc_number
  attr_accessor :cc_expiration
  attr_accessor :cc_cvc

  # If solr's dumb callbacks end up raising an error during creation, the payment will be processed,
  # but not created in CRM.
  def solr_index
    super
  rescue Exception => e
    if order
      order.issue_warning("Solr", "#{e.class.name}: #{e.message} while indexing a payment.")
    end
  end
  def solr_index!
    super
  rescue Exception => e
    if order
      order.issue_warning("Solr", "#{e.class.name}: #{e.message} while indexing a payment.")
    end
  end

  def transaction_id
    case VALID_PAYMENT_METHODS[payment_method]
    when 'Credit Card' then cc_transaction
    when 'PayPal'      then pp_transaction_id
    else nil
    end
  end

  def billing_address
    if address1.blank?
      "<none>"
    else
      "#{address1}, #{city}, #{state}, #{COUNTRY_NAMES[country] || country}"
    end
  end

  def refunded?
    discounts.any?
  end
  alias_method :refunded, :refunded?

  def is_refunded?
    refunded
  end

  def totally_refunded?
    refunded_amount == amount
  end

  def credit_card?
    VALID_PAYMENT_METHODS[payment_method] == 'Credit Card'
  end

  def paypal?
    VALID_PAYMENT_METHODS[payment_method] == 'PayPal'
  end

  def cash?
    VALID_PAYMENT_METHODS[payment_method] == 'Cash'
  end

  def identifier
    "##{id} #{created_at.strftime('%m/%d/%Y')} #{number_to_currency(amount)}"
  end

  def cc_number=(new_cc_number)
    return super if new_cc_number.blank?
    return super if /x+/ =~ new_cc_number

    stored_value = ''
    new_cc_number.each_char.with_index do |c, i|
      if /\s/ =~ c
        stored_value << c
      elsif i >= new_cc_number.size - 4
        stored_value << c
      else
        stored_value << 'x'
      end
    end

    # Only store this in memory
    @actual_cc_number = new_cc_number

    super(stored_value)
  end

  def credit_card
    return @credit_card if @credit_card
    return nil unless credit_card?
    # return nil if actual_cc_number.blank? || cc_expiration.blank? || cc_cvc.blank?

    # (first_name: nonwhitespace)(whitespace)(last_name: nonwhitespace)
    /^(?<first_name>\S+)\s+(?<last_name>.+)$/ =~ cc_name
    # (month: 2 digits)(slash)(year: 2 digits)
    /(?<month>.{2})\/(?<year>.{2})/ =~ cc_expiration

    current_year = Time.now.year.to_s
    if current_year.size > 4
      raise "8000 years have past since the creation of this software!!!"
    end
    # "20" from current year + "19" (for example) from input value for "2019"
    year = "#{current_year[0...2]}#{year}"
    # 'cause this code will definitely still be used 100 years from now.

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      first_name:         first_name,
      last_name:          last_name,
      number:             actual_cc_number.try(:gsub, /\s+/, ''),
      month:              month,
      year:               year,
      verification_value: cc_cvc
    )
  end

  def gateway
    return @gateway if @gateway

    if credit_card?
      @gateway = CREDIT_CARD_GATEWAY.new(
        login:    Setting.payflow_login,
        password: Setting.payflow_password,
        test:     !Rails.env.production?
      )
    elsif paypal?
      @gateway = PAYPAL_GATEWAY.new(
        login:     Setting.paypal_username,
        password:  Setting.paypal_password,
        signature: Setting.paypal_signature,
        test:      !Rails.env.production?
      )
    else nil
    end
  end

  def will_charge_card?
    credit_card? &&
      !Setting.payflow_login.blank? &&
      !Setting.payflow_password.blank?
  end

  def can_do_paypal_express?
    !Setting.paypal_username.blank? &&
    !Setting.paypal_password.blank? &&
    !Setting.paypal_signature.blank?
  end

  def amount_in_cents
    (amount * 100).round
  end

  def retail?
    !retail_description.nil?
  end

  def description
    if retail?
      retail_description.empty? ? "Retail payment" : retail_description
    elsif order
      "SoftWEAR CRM Payment for #{order.name} (##{order.id}) by #{salesperson.try(:full_name) || order.salesperson.try(:full_name)}"
    else
      "Unknown payment (no order or retail description)"
    end
  end

  def purchase!
    return unless errors.full_messages.empty?
    return unless credit_card?
    return if credit_card.nil?
    return if amount.blank?
    return if !retail? && order_id.blank?
    return if salesperson_id.blank?
    return if Setting.payflow_login.blank?
    return if Setting.payflow_password.blank?

    result = gateway.purchase(
      amount_in_cents,
      credit_card,

      order_id: id, # "invoice" id
      description: description,
      comment: order_id,

      billing_address: {
        name:     order.try(:full_name) || cc_name,
        company:  order.try(:company),
        address1: address1,
        city:     city,
        state:    state,
        country:  country,
        zip:      zipcode,
        phone:    order.try(:phone_number)
      }
    )

    if result.success?
      # NOTE pn_ref is basically the transaction ID from Payflow
      self.cc_transaction = result.params['pn_ref']
      self.pp_ref = result.params['pp_ref']
      true
    else
      msg = "- Failed to charge card: #{result.message}"
      errors.add(:payment_method, msg)
      self.cc_transaction = 'ERROR'
      raise PaymentError, msg
    end
  end

  # This is called by Discount after_validation on create (refund_amount should be in dollars)
  def refund!(refund_amount)
    return false unless can_do_refund?
    return false unless errors.full_messages.empty?
    return false unless credit_card? || paypal?
    return false if transaction_id.blank? || transaction_id == 'ERROR'
    return false if refund_amount == 0

    result = gateway.refund(
      (refund_amount * 100).round, # In cents
      transaction_id,

      description: "SoftWEAR CRM Refund by #{salesperson.full_name}. Reason: \"#{refund_reason}\"."
    )

    if result.success?
      true
    else
      msg = "- Failed to refund: #{result.message}"
      raise PaymentError, msg
    end
  end

  def can_do_refund?
    if credit_card?
      !Setting.payflow_login.blank? &&
      !Setting.payflow_password.blank?
    elsif paypal?
      !Setting.paypal_username.blank? &&
      !Setting.paypal_password.blank? &&
      !Setting.paypal_signature.blank?
    else
      false
    end
  end

  def refunded_amount
    discounts.pluck(:amount).reduce(0, :+)
  end

  # Called by Discount during its validation
  def validate_refund(refund)
    refund_total = 0
    came_across_passed_refund = false

    discounts.each do |discount|
      refund_total += discount.amount
      came_across_passed_refund ||= discount.id == refund.id
    end

    refund_total += refund.amount unless came_across_passed_refund

    if refund_total.to_f > amount.to_f
      refund.errors.add(:amount, "exceeds the payment amount (#{number_to_currency amount.to_f})")
    end
  end


  def display_payment_method
    VALID_PAYMENT_METHODS[payment_method]
  end

  def pending_drop
    if order.blank?
      payment_drop_payments.blank?
    else
      payment_drop_payments.blank? && !order.imported_from_admin?
    end
  end

  private

  def credit_card_is_valid
    # This validation is only for newly created credit card payments (to validate the transient stuff)
    return true if persisted? || !cc_transaction.blank?

    if credit_card.nil?
      errors.add(:cc_expiration, 'required') if cc_expiration.blank?
      errors.add(:cc_cvc, 'required') if cc_cvc.blank?
      errors.add(:cc_number, 'must be re-entered') if /x+/ =~ cc_number
      return
    end

    card_errors = credit_card.validate
    unless card_errors.empty?
      if card_errors[:year] || card_errors[:month]
        # Year and month errors go to cc_expiration
        errors.add(:cc_expiration, [card_errors.delete(:year), card_errors.delete(:month)].compact.uniq)
      end
      if card_errors[:verification_value]
        # Verification value errors go to cc_cvc
        errors.add(:cc_cvc, card_errors.delete(:verification_value))
      end
      unless card_errors.empty?
        # The rest will go into cc_number
        card_errors.each do |category, problems|
          if category.to_sym == :number
            problems.each { |problem| errors.add(:cc_number, problem) }
          else
            errors.add(:cc_number, "#{category}: #{problems.join(', ')}")
          end
        end
      end
      return
    end
  end

  def amount_doesnt_overflow_order_balance
    return if order.blank? || amount.blank?

    order_balance = order.balance_excluding(self)
    if is_refunded?
      new_balance = order_balance - (amount - refunded_amount)
    else
      new_balance = order_balance - amount
    end
    if new_balance < 0
      if order_balance == 0
        remark = "(the order's balance is $0.00)"
      else
        remark = "(set to #{number_to_currency(order_balance)} to complete payment)"
      end

      errors.add(
        :amount,
        "overflows the order's balance by #{number_to_currency(-new_balance)} #{remark}"
      )
    end
  end

  def amount_greater_than_zero
    errors.add(:amount, "cannot be negative") if amount && amount < 0
  end

  def recalculate_order_fields
    Order.without_tracking { order.try(:recalculate_payment_total!) }
  end


  def calculate_sales_tax_amount
    return if order.nil?
    self.sales_tax_amount = 0
    tax_balance = order.sales_tax_balance

    self.sales_tax_amount = (amount / order.total) * order.tax
    if sales_tax_amount > tax_balance
      self.sales_tax_amount = tax_balance
    end

    if sales_tax_amount.try(:nan?)
      self.sales_tax_amount = 0
    else
      save(validate: false)
    end
  end
end
