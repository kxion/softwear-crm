require 'spec_helper'
include ApplicationHelper

feature 'Imprint Method Features', imprint_method_spec: true do
  given!(:imprint_method) { create(:valid_imprint_method_with_color_and_location) }
  given!(:valid_user) { create(:alternate_user) }
  background(:each) { sign_in_as(valid_user) }

  scenario 'A user can view a list of imprint methods' do
    visit root_path
    unhide_dashboard
    click_link 'Configuration'
    click_link 'Imprint Methods'
    expect(page).to have_css("tr##{model_table_row_id(imprint_method)}")
  end

  scenario 'A user can add an imprint method', js: true do
    visit imprint_methods_path
    click_link 'Add an Imprint Method'
    fill_in 'Name', with: 'New Imprint Method Name'

    find('#imprint_method_ink_color_names').select InkColor.pluck(:name).sample

    click_link 'Add Print Location'
    find(:css, "input[id^='imprint_method_print_locations_attributes_'][id$='_name']").set('Chest')
    find(:css, "input[id^='imprint_method_print_locations_attributes_'][id$='_max_height']").set('5.5')
    find(:css, "input[id^='imprint_method_print_locations_attributes_'][id$='_max_width']").set('5.5')

    click_button 'Create Imprint Method'

    sleep 2
    expect(ImprintMethod.where(name: 'New Imprint Method Name')).to exist
    expect(page).to have_selector('#flash_notice', text: 'Imprint method was successfully created.')
  end

  scenario 'A user can edit an imprint method' do
    visit imprint_methods_path
    find("tr#imprint_method_#{imprint_method.id} a[data-action='edit']").click
    fill_in 'Name', with: 'Edited Imprint Method Name'
    click_button 'Update Imprint Method'
    expect(imprint_method.reload.name).to eq('Edited Imprint Method Name')
    expect(page).to have_selector('#flash_notice', text: 'Imprint method was successfully updated.')
  end

  scenario 'A user can delete an imprint method', js: true, story_692: true do
    visit imprint_methods_path
    find("tr#imprint_method_#{imprint_method.id} a[data-action='destroy']").click
    sleep 2
    page.driver.browser.switch_to.alert.accept
    wait_for_ajax
    expect(imprint_method.reload.deleted_at).not_to eq(nil)
  end
end
