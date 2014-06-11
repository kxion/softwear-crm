class ImprintableVariant < ActiveRecord::Base
  acts_as_paranoid

  belongs_to :imprintable
  belongs_to :size
  belongs_to :color

  validates :imprintable, presence: true
  validates :size, presence: true
  validates :color, presence: true

  def full_name
    "#{brand.name} #{style.catalog_no} #{size.name} #{color.name}"
  end

  def brand
    self.imprintable.brand
  end

  def style
    self.imprintable.style
  end
end