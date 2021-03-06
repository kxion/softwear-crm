require 'spec_helper'

describe 'artwork_requests/index.html.erb', artwork_request_spec: true do
  let!(:artwork_request) { create(:valid_artwork_request) }
  let!(:current_user) { User.find(artwork_request.artist_id) }

  it 'renders _table.html.erb' do
    allow(view).to receive(:current_user).and_return(current_user)
    assign(:artwork_requests, ArtworkRequest.all.page(1))
    assign(:artwork_request_states,  ArtworkRequest.state_machine.states.map{|x| [x.human_name.humanize, x.name] })
    render
    expect(rendered).to render_template(partial: '_table')
  end
end
