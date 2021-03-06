require 'spec_helper'
include ApiControllerTests

describe Api::SizesController, api_size_spec: true, api_spec: true do
  let!(:valid_user) { create :alternate_user }
  before(:each) { sign_in valid_user }

  it_behaves_like 'api_controller create'
  it_behaves_like 'a retailable api controller'

  before(:each) do
    allow_any_instance_of(Api::SizesController)
      .to receive(:token_authenticate_user!)
      .and_return true
  end

  describe 'GET #index' do
    context 'with valid "color" and "imprintable" parameters' do
      let!(:imprintable) { create :valid_imprintable, common_name: 'Common' }

      it "returns sizes associated with the imprintable's variant by color" do
        expect(Imprintable).to receive(:find_by).with(common_name: 'Common')
          .and_return imprintable

        expect(imprintable)
          .to receive(:sizes_by_color)
          .with('Blue', retail: true)
          .and_return 'test'

        get :index, format: :json, color: 'Blue', imprintable: 'Common'

        expect(assigns(:sizes)).to eq 'test'
      end
    end

    context 'with invalid "color" and "imprintable" parameters' do
      it 'returns 404' do
        get :index, format: :json, color: 'Blue', imprintable: 'Common'

        expect(response.code).to eq '404'
      end
    end
  end
end
