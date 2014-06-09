class Color < ActiveRecord::Base
  default_scope -> { where(deleted_at: nil) }
  scope :deleted, -> { unscoped.where.not(deleted_at: nil) }

  has_many :imprintable_variants

  validates :name, uniqueness: true, presence: true
  validates :sku, uniqueness: true, presence: true

  def destroyed?
    !deleted_at.nil?
  end

  def destroy
    update_attribute(:deleted_at, Time.now)
  end

  def destroy!
    update_column(:deleted_at, Time.now)
  end
end
