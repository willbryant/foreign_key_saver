require 'rubygems'
require 'test/unit'

PROJECT_ROOT=File.expand_path("../../..")
if File.directory?("#{PROJECT_ROOT}/vendor/rails")
  require "#{PROJECT_ROOT}/vendor/rails/railties/lib/initializer"
end
require 'active_record'

raise "use RAILS_ENV=mysql or RAILS_ENV=postgresql to test this plugin" unless %w(mysql postgresql).include?(ENV['RAILS_ENV'])
RAILS_ENV = ENV['RAILS_ENV']
RAILS_ROOT = File.dirname(__FILE__)
TEST_TEMP_DIR = File.join(File.dirname(__FILE__), 'tmp', 'foreign_key_constraints')

database_config = YAML::load(IO.read(File.join(File.dirname(__FILE__), '/database.yml')))
ActiveRecord::Base.establish_connection(database_config[ENV['RAILS_ENV']])

require 'init' # load foreign_key_constraints