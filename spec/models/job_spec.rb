require 'spec_helper'
include LineItemHelpers

describe Job, job_spec: true do
  # Setting name to 'New Job' on create makes this obsolete
  # it { should validate_presence_of :name }
  it { should validate_uniqueness_of(:name).scoped_to(:order_id) }

  it 'should allow two jobs with the same name if one is deleted' do
    job1 = create(:job, name: 'Job Name')
    job1.destroy

    job2 = create(:job, name: 'Job Name')
    expect(job2).to be_valid
  end

  it 'should have many line items' do
    job = create(:job, name: 'job')
    expect(job.line_items).to be_a ActiveRecord::Relation # I think
  end

  context 'imprints', imprint_spec: true do
    it { should have_many :imprints }
  end

  it 'subsequent jobs created with a nil name will be named "New Job #"' do
    job0 = create(:empty_job)
    job1 = create(:empty_job)
    job2 = create(:empty_job)
    expect(job0.name).to eq 'New Job'
    expect(job1.name).to eq 'New Job 2'
    expect(job2.name).to eq 'New Job 3'
  end

  it "deleting a job doesn't stop subsequent job name generation from working" do
    job = create(:empty_job)
    job.destroy
    
    job0 = create(:empty_job)
    job1 = create(:empty_job)
    job2 = create(:empty_job)
    expect(job0.name).to eq 'New Job'
    expect(job1.name).to eq 'New Job 2'
    expect(job2.name).to eq 'New Job 3'
  end

  context '#sort_line_items', line_item_spec: true, sort_line_items: true do
    let!(:job) { create(:job) }
    [:red, :blue, :green].each { |c| let!(c) { create(:valid_color, name: c) } }
    [:shirt, :hat].each { |s| let!(s) { create(:associated_imprintable) } }
    
    make_variants :green, :shirt, [:S, :M, :L]
    make_variants :red,   :shirt, [:S, :M, :XL]
    make_variants :red,   :hat,   [:OSFA]
    make_variants :blue,  :hat,   [:OSFA]

    it 'should organize the line items by imprintable, then color' do
      result = job.sort_line_items

      expect(result.keys).to include shirt.name
      expect(result.keys).to include hat.name

      with(result[shirt.name].keys) do |it|
        expect(it).to include 'green'
        expect(it).to include 'red'
        expect(it).to_not include 'blue'
      end

      with(result[hat.name].keys) do |it|
        expect(it).to include 'red'
        expect(it).to include 'blue'
        expect(it).to_not include 'green'
      end

      with(result[shirt.name]['green']) do |it|
        expect(it).to include green_shirt_s_item
        expect(it).to include green_shirt_m_item
        expect(it).to include green_shirt_l_item
      end

      with(result[hat.name]['blue']) do |it|
        expect(it).to eq [blue_hat_osfa_item]
      end
    end

    it 'should sort the resulting arrays properly', pending: 'Need to review with Nigel' do
      sizes = [size_xl, size_m, size_s]
      sizes.each_with_index do |s,i|
        s.sort_order = i+1
      end
      sizes.each { |s| s.save }

      result = job.sort_line_items

      expect(result[shirt.name]['red'])
      .to eq [red_shirt_s_item, red_shirt_m_item, red_shirt_xl_item]
    end

    it 'should take 6 SQL queries', pending: 'Look into this' do
      expect(queries_after{job.sort_line_items}).to eq 6
    end
  end

  context '#standard_line_items', line_item_spec: true do
    let!(:job) { create(:job) }

    let!(:white) { create(:valid_color, name: 'white') }
    let!(:shirt) { create(:associated_imprintable) }

    make_variants :white, :shirt, [:S, :M, :L]

    5.times { |n| let!("standard#{n}".to_sym) { create(:non_imprintable_line_item, job_id: job.id) } }

    it 'should return all the non-imprintable line items' do
      result = job.standard_line_items
      5.times do |n|
        expect(result).to include send("standard#{n}")
      end
    end

    it 'should not contain any imprintable line items' do
      result = job.standard_line_items
      ['s', 'm', 'l'].each do |s|
        expect(result).to_not include send("white_shirt_#{s}_item")
      end
    end
  end

  it 'should not be deletable when it has line items', line_item_spec: true do
    job = create(:job)
    line_item = create(:non_imprintable_line_item, job_id: job.id)

    job.destroy
    expect(job.destroyed?).to_not be_truthy
    expect(job.errors.messages[:deletion_status]).to include "All line items must be manually removed before a job can be deleted"
  end
end