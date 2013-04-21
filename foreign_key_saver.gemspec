# -*- encoding: utf-8 -*-
require File.expand_path('../lib/foreign_key_saver/version', __FILE__)

spec = Gem::Specification.new do |gem|
  gem.name         = 'foreign_key_saver'
  gem.version      = ForeignKeySaver::VERSION
  gem.summary      = "Adds support for foreign key constraints to ActiveRecord schema operations."
  gem.description  = <<-EOF
Adds a add_foreign_key_constraint schema method, and extends the schema dump code to output these
foreign key constraints.

Only MySQL and PostgreSQL are currently supported.


Examples
========

# adds a constraint on projects.customer_id with parent customers.id
add_foreign_key :projects, :customer_id, :customers, :id

# adds a constraint on projects(a, b) with parent(a, b) with the default RESTRICT update/delete actions
add_foreign_key "child", ["a", "b"], "parent", ["a", "b"]

# adds a constraint with the ON UPDATE action set to CASCADE and the ON DELETE action set to SET NULL
add_foreign_key 'projects', 'customer_id', 'customers', 'id', :on_update => :cascade, :on_delete => :set_null

The following actions are defined:
  :restrict
  :no_action
  :cascade
  :set_null (aka :nullify)
  :set_default
Note that MySQL does not support :set_default, and also treats :no_action as :restrict.


Compatibility
=============

Supports mysql, mysql2, postgresql.

Currently tested against Rails 3.2.13 on 2.0.0p0 and Rails 3.2.13, 3.1.8, 3.0.17, and 2.3.14 on Ruby 1.8.7.
EOF
  gem.has_rdoc     = false
  gem.author       = "Will Bryant"
  gem.email        = "will.bryant@gmail.com"
  gem.homepage     = "http://github.com/willbryant/foreign_key_saver"
  
  gem.executables  = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files        = `git ls-files`.split("\n")
  gem.test_files   = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.require_path = "lib"
  
  gem.add_dependency "activerecord"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "mysql"
  gem.add_development_dependency "mysql2"
  gem.add_development_dependency "pg"
end
