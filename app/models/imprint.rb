class Imprint < ActiveRecord::Base
  include TrackingHelpers

  attr_reader :name_number_expected

  acts_as_paranoid

  tracked by_current_user + on_order

  belongs_to :job
  belongs_to :print_location
  has_many :name_numbers
  has_one :imprint_method, through: :print_location
  has_many :ink_colors, through: :imprint_method
  has_many :artwork_request_imprints
  has_many :artwork_requests, through: :artwork_request_imprints
  has_many :possible_artworks, through: :artwork_requests, source: :artworks

  validates :job, presence: true
  validates :print_location, presence: true, uniqueness: { scope: :job_id }

  scope :name_number, -> { joins(:imprint_method).where(imprint_methods: { name: 'Name/Number' }) }

  def name
    "#{imprint_method.try(:name) || 'n\a'} - #{print_location.try(:name) || 'n\a'}"
  end

  def artworks
    possible_artworks
      .joins(:proofs)
      .where(proofs: { job_id: job_id })
  end
end
