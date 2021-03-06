class StoresController < InheritedResources::Base
  before_filter :sales_manager_only, only: [:create, :update, :destroy, :edit]
  before_action :set_current_action

  def index
    super do |format|
      format.html
      format.json { render json: @stores.where('name like ?', "%#{params[:q]}%") }
    end
  end

  def update
    super do |format|
      format.html { redirect_to stores_path }
    end
  end

  def show
    super do |format|
      format.html { redirect_to stores_path }
    end
  end

  protected

  def set_current_action
    @current_action = 'stores'
  end

  private

  def permitted_params
    params.permit(store: [:name, :address_1, :address_2, :city, :state, :zip, 
                  :country, :phone, :zipcode, :sales_email, 
                  logo_attributes: [
                   :file, :description, :id, :_destroy
                  ]
                ])
  end
end
