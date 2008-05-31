require File.join(File.dirname(__FILE__), 'test_helper')

class ForeignKeyConstraintsTest < Test::Unit::TestCase
  def schema_dump
    stream = StringIO.new
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    stream.rewind
    stream.read
  end
  
  def schema(&block)
    ActiveRecord::Schema.define(:version => 1, &block)
    schema_dump
  end
  
  def test_constraints_to_dump
    assert_equal '"ac", "parent", "ap", :name => "cn"',
      ActiveRecord::ForeignKeyConstraint.new('cn', 'ac', 'parent', 'ap').to_dump
      
    assert_equal '["ac", "bc"], "parent", ["ap", "bp"], :name => "cn"',
      ActiveRecord::ForeignKeyConstraint.new('cn', ['ac', 'bc'], 'parent', ['ap', 'bp']).to_dump
      
    assert_equal '"ac", "parent", "ap", :name => "cn", :on_update => :cascade',
      ActiveRecord::ForeignKeyConstraint.new('cn', 'ac', 'parent', 'ap', :cascade).to_dump
  
    assert_equal '"ac", "parent", "ap", :name => "cn", :on_delete => :set_default',
      ActiveRecord::ForeignKeyConstraint.new('cn', 'ac', 'parent', 'ap', nil, :set_default).to_dump
  
    assert_equal '"ac", "parent", "ap", :name => "cn", :on_update => :set_null, :on_delete => :no_action',
      ActiveRecord::ForeignKeyConstraint.new('cn', 'ac', 'parent', 'ap', :set_null, :no_action).to_dump
  end
  
  if ActiveRecord::Base.connection.is_a?(ActiveRecord::ConnectionAdapters::MysqlAdapter)
    def test_mysql_constraints_to_sql
      assert_equal 'CONSTRAINT `cn` FOREIGN KEY (`ac`) REFERENCES `parent` (`ap`) ON UPDATE RESTRICT ON DELETE RESTRICT',
        ActiveRecord::ForeignKeyConstraint.new('cn', 'ac', 'parent', 'ap').to_sql(ActiveRecord::Base.connection)
      
      assert_equal 'CONSTRAINT `cn` FOREIGN KEY (`ac`, `bc`) REFERENCES `parent` (`ap`, `bp`) ON UPDATE RESTRICT ON DELETE RESTRICT',
        ActiveRecord::ForeignKeyConstraint.new('cn', ['ac', 'bc'], 'parent', ['ap', 'bp']).to_sql(ActiveRecord::Base.connection)
      
      assert_equal 'CONSTRAINT `cn` FOREIGN KEY (`ac`) REFERENCES `parent` (`ap`) ON UPDATE CASCADE ON DELETE RESTRICT',
        ActiveRecord::ForeignKeyConstraint.new('cn', 'ac', 'parent', 'ap', :cascade).to_sql(ActiveRecord::Base.connection)
  
      assert_equal 'CONSTRAINT `cn` FOREIGN KEY (`ac`) REFERENCES `parent` (`ap`) ON UPDATE RESTRICT ON DELETE SET DEFAULT',
        ActiveRecord::ForeignKeyConstraint.new('cn', 'ac', 'parent', 'ap', nil, :set_default).to_sql(ActiveRecord::Base.connection)
  
      assert_equal 'CONSTRAINT `cn` FOREIGN KEY (`ac`) REFERENCES `parent` (`ap`) ON UPDATE SET NULL ON DELETE NO ACTION',
        ActiveRecord::ForeignKeyConstraint.new('cn', 'ac', 'parent', 'ap', :set_null, :no_action).to_sql(ActiveRecord::Base.connection)
    end
  else
    def test_constraints_to_sql
      assert_equal 'CONSTRAINT "cn" FOREIGN KEY ("ac") REFERENCES parent ("ap") ON UPDATE RESTRICT ON DELETE RESTRICT',
        ActiveRecord::ForeignKeyConstraint.new('cn', 'ac', 'parent', 'ap').to_sql(ActiveRecord::Base.connection)

      assert_equal 'CONSTRAINT "cn" FOREIGN KEY ("ac", "bc") REFERENCES parent ("ap", "bp") ON UPDATE RESTRICT ON DELETE RESTRICT',
        ActiveRecord::ForeignKeyConstraint.new('cn', ['ac', 'bc'], 'parent', ['ap', 'bp']).to_sql(ActiveRecord::Base.connection)

      assert_equal 'CONSTRAINT "cn" FOREIGN KEY ("ac") REFERENCES parent ("ap") ON UPDATE CASCADE ON DELETE RESTRICT',
        ActiveRecord::ForeignKeyConstraint.new('cn', 'ac', 'parent', 'ap', :cascade).to_sql(ActiveRecord::Base.connection)

      assert_equal 'CONSTRAINT "cn" FOREIGN KEY ("ac") REFERENCES parent ("ap") ON UPDATE RESTRICT ON DELETE SET DEFAULT',
        ActiveRecord::ForeignKeyConstraint.new('cn', 'ac', 'parent', 'ap', nil, :set_default).to_sql(ActiveRecord::Base.connection)

      assert_equal 'CONSTRAINT "cn" FOREIGN KEY ("ac") REFERENCES parent ("ap") ON UPDATE SET NULL ON DELETE NO ACTION',
        ActiveRecord::ForeignKeyConstraint.new('cn', 'ac', 'parent', 'ap', :set_null, :no_action).to_sql(ActiveRecord::Base.connection)
    end
  end
  
  def test_mysql_columns_from_sql
    assert_equal ['abc'],               ActiveRecord::ConnectionAdapters::MysqlAdapter.columns_from_sql('`abc`')
    assert_equal ['abc', 'def'],        ActiveRecord::ConnectionAdapters::MysqlAdapter.columns_from_sql('`abc`, `def`')
    assert_equal ['abc', 'def', 'ghi'], ActiveRecord::ConnectionAdapters::MysqlAdapter.columns_from_sql('`abc`, `def`, `ghi`')
  end
  
  def test_mysql_constraints_from_sql
    assert_equal [ActiveRecord::ForeignKeyConstraint.new('cn', 'ac', 'parent', 'ap')], ActiveRecord::ConnectionAdapters::MysqlAdapter.
      constraints_from_sql('CONSTRAINT `cn` FOREIGN KEY (`ac`) REFERENCES `parent` (`ap`)')
      
    assert_equal [ActiveRecord::ForeignKeyConstraint.new('cn', ['ac', 'bc'], 'parent', ['ap', 'bp'])], ActiveRecord::ConnectionAdapters::MysqlAdapter.
      constraints_from_sql('CONSTRAINT `cn` FOREIGN KEY (`ac`, `bc`) REFERENCES `parent` (`ap`, `bp`)')
      
    assert_equal [ActiveRecord::ForeignKeyConstraint.new('cn', 'ac', 'parent', 'ap', :cascade)], ActiveRecord::ConnectionAdapters::MysqlAdapter.
      constraints_from_sql('CONSTRAINT `cn` FOREIGN KEY (`ac`) REFERENCES `parent` (`ap`) ON UPDATE CASCADE')
  
    assert_equal [ActiveRecord::ForeignKeyConstraint.new('cn', 'ac', 'parent', 'ap', nil, :set_default)], ActiveRecord::ConnectionAdapters::MysqlAdapter.
      constraints_from_sql('CONSTRAINT `cn` FOREIGN KEY (`ac`) REFERENCES `parent` (`ap`) ON DELETE SET DEFAULT')
  
    assert_equal [ActiveRecord::ForeignKeyConstraint.new('cn', 'ac', 'parent', 'ap', :set_null, :no_action)], ActiveRecord::ConnectionAdapters::MysqlAdapter.
      constraints_from_sql('CONSTRAINT `cn` FOREIGN KEY (`ac`) REFERENCES `parent` (`ap`) ON DELETE NO ACTION ON UPDATE SET NULL') # mysql has update and delete kinda around the wrong way
  end
  
  def test_fkc_define_roundtrip
    dump = schema do
      drop_table :child rescue nil
      drop_table :parent rescue nil
      create_table "parent" do end
      create_table "child"  do |t| t.integer :parent_id end
      add_foreign_key_constraint "child", "parent_id", "parent", "id"
    end
    assert_match /create_table "parent"/, dump
    assert_match /add_foreign_key_constraint "child", "parent_id", "parent", "id"/, dump
  end
  
  def test_remove_fkc
    dump = schema do
      drop_table :child rescue nil
      drop_table :parent rescue nil
      create_table "parent" do end
      create_table "child"  do |t| t.integer :parent_id end
      add_foreign_key_constraint "child", "parent_id", "parent", "id", :name => 'test_fk_name'
      remove_foreign_key_constraint "child", "test_fk_name"
    end
    assert_no_match /add_foreign_key_constraint "child"/, dump
  end
  
  def test_drop_parent_with_child_fkcs
    dump = schema do
      drop_table :child rescue nil
      drop_table :parent rescue nil
      create_table "parent" do end
      create_table "child"  do |t| t.integer :parent_id end
      add_foreign_key_constraint "child", "parent_id", "parent", "id"
      drop_table :parent
    end
    assert_no_match /create_table "parent"/, dump
    assert_no_match /add_foreign_key_constraint "child", "parent_id", "parent", "id"/, dump
  end
  
  def test_force_table_create
    dump = schema do
      drop_table :child rescue nil
      drop_table :parent rescue nil
      create_table "parent" do end
      create_table "child"  do |t| t.integer :parent_id end
      add_foreign_key_constraint "child", "parent_id", "parent", "id"
      create_table "parent", :force => true do end
      create_table "child",  :force => true do |t| t.integer :parent_id end
      add_foreign_key_constraint "child", "parent_id", "parent", "id"
      create_table "child",  :force => true do |t| t.integer :parent_id end
      create_table "parent", :force => true do end
      add_foreign_key_constraint "child", "parent_id", "parent", "id"
    end
    assert_match /create_table "parent"/, dump
    assert_match /add_foreign_key_constraint "child", "parent_id", "parent", "id"/, dump
  end
  
  def test_fkc_composite_key
    dump = schema do
      create_table :parent, :force => true do |t| t.integer :afield end
      add_index :parent, [:id, :afield], :unique => true
      create_table :child,  :force => true do |t| t.integer :parent_id, :afield end
      add_foreign_key_constraint :child, [:parent_id, :afield], :parent, [:id, :afield]
    end
    assert_match /add_foreign_key_constraint "child", \["parent_id", "afield"\], "parent", \["id", "afield"\]/, dump
  end
  
  def test_define_actions
    dump = schema do
      create_table "parent", :force => true do end
      create_table "child",  :force => true do |t| t.integer :parent_id end
      add_foreign_key_constraint "child", "parent_id", "parent", "id", :on_update => :cascade, :on_delete => :set_null
    end
    assert_match /add_foreign_key_constraint "child", "parent_id", "parent", "id", :name => "\w+", :on_update => :cascade, :on_delete => :set_null/, dump
  end
  
  def test_no_extraneous_actions_in_dump
    dump = schema do
      create_table "parent", :force => true do end
      create_table "child",  :force => true do |t| t.integer :parent_id end
      add_foreign_key_constraint "child", "parent_id", "parent", "id", :on_delete => :restrict
    end
    assert_no_match /add_foreign_key_constraint "child".*on_update/, dump
    assert_no_match /add_foreign_key_constraint "child".*on_delete/, dump
  end
  
  def test_explicit_names
    dump = schema do
      create_table "parent", :force => true do end
      create_table "child",  :force => true do |t| t.integer :parent_id end
      add_foreign_key_constraint "child", "parent_id", "parent", "id", :name => 'test_fk_name'
    end
    assert_match /add_foreign_key_constraint "child", "parent_id", "parent", "id", :name => "test_fk_name"/, dump
  end
  
  def test_multiple_parents
    dump = schema do
      create_table "parent1", :force => true do end
      create_table "parent2", :force => true do end
      create_table "child",  :force => true do |t| t.integer :parent1_id, :parent2_id end
      add_foreign_key_constraint "child", "parent1_id", "parent1", "id"
      add_foreign_key_constraint "child", "parent2_id", "parent2", "id"
    end
    assert_match /add_foreign_key_constraint "child", "parent1_id", "parent1", "id"/, dump
    assert_match /add_foreign_key_constraint "child", "parent2_id", "parent2", "id"/, dump
  end
  
  def test_multiple_children
    dump = schema do
      create_table "parent", :force => true do end
      create_table "child1",  :force => true do |t| t.integer :parent_id end
      create_table "child2",  :force => true do |t| t.integer :parent_id end
      add_foreign_key_constraint "child1", "parent_id", "parent", "id"
      add_foreign_key_constraint "child2", "parent_id", "parent", "id"
    end
    assert_match /add_foreign_key_constraint "child1", "parent_id", "parent", "id"/, dump
    assert_match /add_foreign_key_constraint "child2", "parent_id", "parent", "id"/, dump
  end
  
  def test_remove_only_named
    dump = schema do
      create_table "parent1", :force => true do end
      create_table "parent2", :force => true do end
      create_table "child1",  :force => true do |t| t.integer :parent1_id, :parent2_id end
      create_table "child2",  :force => true do |t| t.integer :parent1_id, :parent2_id end
      add_foreign_key_constraint "child1", "parent1_id", "parent1", "id", :name => "test_a"
      add_foreign_key_constraint "child1", "parent2_id", "parent2", "id", :name => "test_b"
      add_foreign_key_constraint "child2", "parent1_id", "parent1", "id", :name => "test_c"
      add_foreign_key_constraint "child2", "parent2_id", "parent2", "id", :name => "test_d"
      remove_foreign_key_constraint :child1, :test_b
    end
    assert_match /add_foreign_key_constraint "child1", "parent1_id", "parent1", "id", :name => "test_a"/, dump
    assert_no_match /add_foreign_key_constraint "child1", "parent2_id", "parent2", "id", :name => "test_b"/, dump
    assert_match /add_foreign_key_constraint "child2", "parent1_id", "parent1", "id", :name => "test_c"/, dump
    assert_match /add_foreign_key_constraint "child2", "parent2_id", "parent2", "id", :name => "test_d"/, dump
  end
end
