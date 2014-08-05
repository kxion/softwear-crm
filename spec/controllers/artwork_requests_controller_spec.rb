require 'spec_helper'
include ApplicationHelper

describe ArtworkRequestsController, js: true, artwork_request_spec: true do

  let!(:valid_user) { create :alternate_user }
  before(:each) { sign_in valid_user }
  let!(:artwork_request){ create(:valid_artwork_request) }
  let!(:order){ create(:order_with_job) }

  describe 'GET show' do
    let!(:imprint_method) {create(:valid_imprint_method_with_color_and_location)}

    it 'renders show.js.erb' do
      get :show,
          order_id: order.id,
          id: artwork_request.id,
          artwork_request: attributes_for(:valid_artwork_request).
              merge(artist_id: create(:user).id,
                  imprint_method_id: imprint_method.id,
                  salesperson_id: create(:alternate_user).id,
                  print_location_id: imprint_method.print_locations.first.id,
                  job_ids: create(:order_with_job).job_ids,
                  ink_color_ids: imprint_method.ink_color_ids),
          format: 'js'
      expect(response).to render_template('show')
    end
  end

  describe 'GET index' do
    it 'renders index.js.erb' do
      get :index,
          order_id: order.id,
          artwork_request_id: artwork_request.id,
          format: 'js'
      expect(response).to render_template('index')
    end
  end

  describe 'GET new' do
    it 'renders new.js.erb' do
      get :new,
          order_id: order.id,
          artwork_request_id: artwork_request.id,
          format: 'js'
      expect(response).to render_template('new')
    end
  end

  describe 'GET edit' do
    it 'renders edit.js.erb' do
      get :edit,
          order_id: order.id,
          id: artwork_request.id,
          format: 'js'
      expect(response).to render_template('edit')
    end
  end

  describe 'POST create' do
    let!(:imprint_method) { create(:valid_imprint_method_with_color_and_location) }
    let!(:args) {
      [
          :create,
          artwork_request: attributes_for(:valid_artwork_request).
              merge(artist_id: create(:user).id,
                  imprint_method_id: imprint_method.id,
                  salesperson_id: create(:alternate_user).id,
                  print_location_id: imprint_method.print_locations.first.id,
                  job_ids: create(:order_with_job).job_ids,
                  ink_color_ids: imprint_method.ink_color_ids)
      ]
    }

    it 'renders create.js.erb' do
      post :create,
           order_id: order.id,
           artwork_request: attributes_for(:valid_artwork_request).
               merge(artist_id: create(:user).id,
                   imprint_method_id: imprint_method.id,
                   salesperson_id: create(:alternate_user).id,
                   print_location_id: imprint_method.print_locations.first.id,
                   job_ids: create(:order_with_job).job_ids,
                   ink_color_ids: imprint_method.ink_color_ids),
           format: 'js'
      expect(response).to render_template('create')


    end

    it "sends an email to the artist's email address" do
      expect(ArtistMailer).to receive(:artist_notification).with(an_instance_of(ArtworkRequest), 'create').and_return( double("Mailer", deliver: true) )
      post :create, order_id: order.id, artwork_request: attributes_for(:valid_artwork_request).merge(artist_id: create(:user).id,
                                                                                                      imprint_method_id: imprint_method.id,
                                                                                                      salesperson_id: create(:alternate_user).id,
                                                                                                      print_location_id: imprint_method.print_locations.first.id,
                                                                                                      job_ids: create(:order_with_job).job_ids,
                                                                                                      ink_color_ids: imprint_method.ink_color_ids), format: 'js'
    end
  end

  describe 'DELETE destroy' do
    it 'renders destroy.js.erb' do
      delete :destroy,
             order_id: order.id,
             id: artwork_request.id,
             format: 'js'
      expect(response).to render_template('destroy')
    end
  end

  describe 'PUT update' do
    let!(:imprint_method) { create(:valid_imprint_method_with_color_and_location) }
    let!(:args) { [:create, artwork_request: attributes_for(:valid_artwork_request).merge(artist_id: create(:user).id,
                                                                                          imprint_method_id: imprint_method.id,
                                                                                          salesperson_id: create(:alternate_user).id,
                                                                                          print_location_id: imprint_method.print_locations.first.id,
                                                                                          job_ids: create(:order_with_job).job_ids,
                                                                                          ink_color_ids: imprint_method.ink_color_ids)] }
    context 'params[:artwork_id] is nil' do
      it 'renders update.js.erb' do

        put :update, order_id: order.id, id: artwork_request.id, artwork_request: attributes_for(:valid_artwork_request).merge(artist_id: create(:user).id,
                                                                                                                               imprint_method_id: imprint_method.id,
                                                                                                                               salesperson_id: create(:alternate_user).id,
                                                                                                                               print_location_id: imprint_method.print_locations.first.id,
                                                                                                                               job_ids: create(:order_with_job).job_ids,
                                                                                                                               ink_color_ids: imprint_method.ink_color_ids), format: 'js'
        expect(response).to render_template('update')


      end
      it "sends an email to the artist's email address" do
        expect(ArtistMailer).to receive(:artist_notification).with(artwork_request, 'update').and_return( double("Mailer", deliver: true) )
        put :update, order_id: order.id, id: artwork_request.id, artwork_request: attributes_for(:valid_artwork_request).merge(artist_id: create(:user).id,
                                                                                                                               imprint_method_id: imprint_method.id,
                                                                                                                               salesperson_id: create(:alternate_user).id,
                                                                                                                               print_location_id: imprint_method.print_locations.first.id,
                                                                                                                               job_ids: create(:order_with_job).job_ids,
                                                                                                                               ink_color_ids: imprint_method.ink_color_ids), format: 'js'
      end
    end

    context 'params[:artwork_id] is not nil and [:remove_artwork] is true' do

      it 'renders update.js.erb and removes the artwork from the artwork request' do

        put :update, id: artwork_request.id, remove_artwork: true , artwork_id: create(:valid_artwork).id, format: 'js'
        expect(response).to render_template('update')
        expect(artwork_request.artworks).to be_empty
      end

      it "doesn't send an email to the artist's email address" do
        expect(ArtistMailer).to_not receive(:artist_notification)
        put :update, id: artwork_request.id, remove_artwork: true , artwork_id: create(:valid_artwork).id, format: 'js'
      end
    end

    context 'params[:artwork_id] is not nil and [:remove_artwork] is nil' do

      it 'renders update.js.erb and adds the artwork to the artwork request' do

        put :update, id: artwork_request.id , artwork_id: create(:valid_artwork).id, format: 'js'
        expect(response).to render_template('update')
        expect(artwork_request.artworks).to_not be_empty
      end

      it "doesn't send an email to the artist's email address" do
        expect(ArtistMailer).to_not receive(:artist_notification).with(artwork_request, 'update')
        put :update, id: artwork_request.id, artwork_id: create(:valid_artwork).id, format: 'js'

      end
    end

  end
end