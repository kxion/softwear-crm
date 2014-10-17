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

    before_action :authenticate_user!

    def index(&block)
      yield if block_given?

      if records.nil?
        instance_variable_set(
          "@#{self.class.model_name.pluralize.underscore}",

          resource_class
            .where(Hash[permitted_attributes.map { |a| [a, params[a]] }])
        )
      end

      respond_to do |format|
        format.json(&render_json(records))
      end
    end

    def show
      super do |format|
        format.json(&render_json)
      end
    end

    def create
      super do |format|
        response.headers['Location'] = collection_url(record)
        format.json(&render_json)
      end
    end

    def update
      super do |format|
        format.json(&render_json)
      end
    end

    protected

    def render_json(records = nil)
      proc do
        render json: (records || record),
               methods: [[:id] + permitted_attributes],
               include: includes
      end
    end

    def self.model_name
      name.gsub('Api::', '').gsub('Controller', '').singularize
    end

    # Override this to specify the :include option of rendering json.
    def includes
      {}
    end

    def records
      instance_variable_get("@#{self.class.model_name.underscore.pluralize}")
    end

    def record
      instance_variable_get("@#{self.class.model_name.underscore}")
    end

    alias_method :params!, :params
    def params
      super.permit(*permitted_params)
    end

    def permitted_attributes
      []
    end

    def permitted_params
      model_attributes = if permitted_attributes.empty?
        {}
      else
        { self.class.model_name.underscore => send(:permitted_attributes) }
      end
      
      usual_params = [:id]

      [usual_params, model_attributes]
    end

    private
  end
end