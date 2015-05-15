class ImprintableGroup < ActiveRecord::Base
  validates :name, uniqueness: true, presence: true
  has_many :imprintable_imprintable_groups
  has_many :imprintables, through: :imprintable_imprintable_groups

  accepts_nested_attributes_for :imprintable_imprintable_groups, allow_destroy: true

  def default_imprintable_for_tier(tier)
    imprintable_imprintable_groups
      .where(tier: tier, default: true)
      .first
      .try(:imprintable)\
        or
    imprintable_imprintable_groups
      .where(tier: tier)
      .first
      .try(:imprintable)
  end
end
