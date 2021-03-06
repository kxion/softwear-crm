class FbaProduct < ActiveRecord::Base
  has_many :fba_skus, dependent: :destroy

  accepts_nested_attributes_for :fba_skus, allow_destroy: true

  validates :name, presence: true, uniqueness: true
  validates :sku, presence: true

  searchable do
    text :name, :sku, :fba_sku_skus
    string :name
    string :sku
    integer :child_sku_count
    integer :id
  end

  def spreadsheet=
  end

  def child_sku_count
    fba_skus.size
  end

  def fba_sku_skus
    fba_skus.pluck(:sku)
  end
end
