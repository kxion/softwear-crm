module Api
  class ApiController < ActionController::Base
    include InheritedResources::Actions
    include InheritedResources::BaseHelpers
    extend  InheritedResources::ClassMethods
    extend  InheritedResources::UrlHelpers
    respond_to :json
    self.responder = InheritedResources::Responder

    self.class_attribute :resource_class, :instance_writer => false unless self.respond_to? :resource_class
    self.class_attribute :parents_symbols,  :resources_configuration, :instance_writer => false

    before_filter :permit_id, only: [:show, :update, :destroy]

    def index
      instance_variable_set(
        "@#{self.class.model_name.pluralize.underscore}",
        (records || resource_class).where(params.permit(permitted_attributes))
      )

      respond_to do |format|
        format.json do
          render json: records, include: includes
        end
      end
    end

    def show
      super do |format|
        format.json do
          render json: record, include: includes
        end
      end
    end

    def create

    end

    def update
      super do |format|
        render json: record, include: includes
      end
    end

    protected

    def self.model_name
      name.gsub('Api::', '').gsub('Controller', '').singularize
    end

    # Override this to specify which attributes can be filtered on.
    # [:name, :age] would allow a remote ActiveResource to 
    # query where(name: 'Whoever', age: 22)
    def permitted_attributes
      []
    end

    # Override this to specify the :include option of rendering json.
    def includes
      nil
    end

    def records
      instance_variable_get("@#{self.class.model_name.underscore.pluralize}")
    end

    def record
      instance_variable_get("@#{self.class.model_name.underscore}")
    end

    private

    def permit_id
      params.permit :id
    end
  end
end