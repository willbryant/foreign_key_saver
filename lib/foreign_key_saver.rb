Rails::Application.initializer :load_foreign_key_saver, :before => :load_config_initializers do
  require 'foreign_key_saver/foreign_key_saver_patches'
end
