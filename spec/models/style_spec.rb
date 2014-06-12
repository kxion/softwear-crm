require 'spec_helper'

describe Style, style_spec: true do

  describe 'Relationships' do
    it { should belong_to(:brand) }
    it { should have_one(:imprintable) }
  end
  describe 'Validations' do
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }

    it { should validate_presence_of(:sku) }
    it { should validate_uniqueness_of(:sku) }
    it { should ensure_length_of(:sku).is_equal_to(2) }

    it { should validate_presence_of(:catalog_no) }
    it { should validate_uniqueness_of(:catalog_no) }

    it { should validate_presence_of(:brand) }
  end

  describe '#find_brand' do
    let!(:style) { create(:valid_style) }

    it 'returns the id of the brand associated with the style' do
      brand = style.find_brand
      expect(brand.id).to eq(style.brand.id)
    end
  end
end
