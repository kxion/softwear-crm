require 'spec_helper'

describe Api::ImprintablesController, api_imprintable_spec: true, api_spec: true do
  it_behaves_like 'api_controller create'
end