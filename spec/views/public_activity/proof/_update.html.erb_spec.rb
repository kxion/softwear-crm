require 'spec_helper'

describe 'public_activity/proof/_update.html.erb', proof_spec: true do
  let!(:activity){ create(:proof_activity) }
  let!(:current_user) { create :user }

  it 'has trackable_type, trackable, and recipient' do
    render partial: 'public_activity/proof/update', locals: {activity: activity, current_user: current_user}
    expect(rendered).to have_text('Updated proof by ' + current_user.full_name + ' in')
    expect(rendered).to have_selector('a', text: activity.recipient.name)
  end

  it 'has trackable_type and recipient but not trackable' do
    activity.trackable_id = nil
    render partial: 'public_activity/proof/update', locals: {activity: activity, current_user: current_user}
    expect(rendered).to have_text('Updated proof which has since been removed in')
    expect(rendered).to have_selector('a', text: activity.recipient.name)
  end

  it 'doesnt have trackable_type but does have recipient' do
    activity.trackable = nil
    render partial: 'public_activity/proof/update', locals: {activity: activity, current_user: current_user}
    expect(rendered).to have_text('Updated some proof... in')
    expect(rendered).to have_selector('a', text: activity.recipient.name)
  end

  it 'doesnt have trackable_type or recipient' do
    activity.trackable = nil
    activity.recipient = nil
    render partial: 'public_activity/proof/update', locals: {activity: activity, current_user: current_user}
    expect(rendered).to have_text('Updated some proof... in a deleted order')
  end

end