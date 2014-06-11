class ImprintablesController < InheritedResources::Base

  def update
    super do |format|
      color_ids = params[:color_ids]
      size_ids = params[:size_ids]
      if color_ids && size_ids
        color_ids.each do |color_id|
          size_ids.each do |size_id|
            ImprintableVariant.create(:imprintable_id => params[:id], :size_id => size_id, :color_id => color_id)
          end
        end
      end
      format.html { redirect_to edit_imprintable_path params[:id] }
    end
  end

  def show
    super do |format|
      format.html { redirect_to edit_imprintable_path params[:id] }
    end
  end

  def create
    super do |format|
      format.html { redirect_to imprintables_path params }
    end
  end

  def update_imprintable_variants
    variants_to_add = params[:update][:variants_to_add]
    variants_to_remove = params[:update][:variants_to_remove]
    if !variants_to_add.nil?
      variants_to_add.each_value do |hash|
        size_id = hash['size_id']
        color_id = hash['color_id']
        ImprintableVariant.create(:imprintable_id => params[:id], :size_id => size_id, :color_id => color_id)
      end
    end
    if !variants_to_remove.nil?
      variants_to_remove.each do |imprintable_variant_id|
        ImprintableVariant.delete(imprintable_variant_id)
      end
    end
    render :json => {}
  end

  private

  def permitted_params
    params.permit(imprintable:
                    [:flashable,
                     :polyester,
                     :special_considerations,
                     :style_id,
                     :color_check,
                     :size_check,
                     :sizing_category])
  end
end