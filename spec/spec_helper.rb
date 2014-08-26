# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'rake'
require 'paperclip/matchers'
require 'public_activity/testing'
require 'email_spec'
# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }
include SunspotHelpers

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.check_pending! if defined?(ActiveRecord::Migration)

I18n.enforce_available_locales = false

RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods
  config.include FormHelpers
  config.include AuthenticationHelpers
  config.include GeneralHelpers
  config.include Devise::TestHelpers, type: :controller
  config.extend ControllerMacros, type: :view
  config.include Devise::TestHelpers, type: :view
  config.include SunspotMatchers
  config.include SunspotHelpers
  config.include Paperclip::Shoulda::Matchers
  config.include EmailSpec::Helpers
  config.include EmailSpec::Matchers
  config.include FormBuilderHelpers

  PublicActivity.enabled = false

  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  config.alias_it_should_behave_like_to :it_can, 'can'

  Capybara.register_driver :selenium do |app|
    Capybara::Selenium::Driver.new(app, :browser => :chrome)
  end

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = false

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  config.order = 'random'

  require 'rack_session_access/capybara'

  config.before(:each) do |example|
    example.metadata[:solr] ? lazy_load_solr : refresh_sunspot_session_spy
  end

  config.after(:suite) do
    stop_solr if solr_running?
  end

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
  end
  config.before(:each) do
    DatabaseCleaner.start
  end
  config.after(:each) do
    DatabaseCleaner.clean
  end

end
