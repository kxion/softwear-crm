class OrdersController < InheritedResources::Base
  before_filter :format_in_hand_by, only: [:create, :update]

  def index
    super do
      @orders = Order.all.page(params[:page])
    end
  end

  def update
    super do |success, failure|
      success.html { redirect_to edit_order_path(params[:id], anchor: 'details') }
      failure.html do
        assign_activities
        render action: :edit, anchor: 'details'
      end
    end
  end

  def show
    redirect_to action: :edit
  end

  def new
    super do
      @current_user = current_user
      stores = Store.all
      @empty = stores.empty?
    end
  end

  def edit
    super do
      assign_activities
    end
  end

  private

  def format_in_hand_by
    unless params[:order].nil? || params[:order][:in_hand_by].nil?
      in_hand_by = params[:order][:in_hand_by]
      params[:order][:in_hand_by] = format_time(in_hand_by)
    end
  end

  def assign_activities
    @activities = @order.all_activities
  end

  def permitted_params
    params.permit(order: [
      :email, :firstname, :lastname,
      :company, :twitter, :name, :po,
      :in_hand_by, :terms, :tax_exempt,
      :tax_id_number, :redo_reason,
      :delivery_method, :phone_number, :commission_amount,
      :store_id, :salesperson_id, :total
    ])
  end
end
