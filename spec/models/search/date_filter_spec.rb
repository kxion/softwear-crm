require 'spec_helper'

describe Search::DateFilter, search_spec: true do
  it { expect(subject.class.ancestors).to include Search::FilterType }

  it { should have_db_column :field }
  it { should have_db_column :relation }
  it { should ensure_inclusion_of(:relation).in_array ['>', '<', '='] }
  it { should have_db_column :negate }
  it { should have_db_column :value }

  let(:query) { create :query }
  let(:order_model) { create :search_order_model, query_id: query.id }

  let(:date) { 5.days.ago }

  let!(:filter) { create :filter_type_date,
    value: date,
    relation: '>',
    field: 'in_hand_by' }

  it 'should apply properly with negate set to false' do
    filter.negate = false
    filter.relation = '='
    filter.save

    Order.search do
      filter.apply(self)
    end
    expect(Sunspot.session).to have_search_params(:with, :in_hand_by, date)
  end

  it 'should apply properly with negate set to true' do
    filter.negate = true
    filter.save

    Order.search do
      filter.apply(self)
    end
    expect(Sunspot.session).to have_search_params(:without) {
      without(:in_hand_by).greater_than(date)
    }
  end
end