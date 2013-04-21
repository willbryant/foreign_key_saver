require 'active_record'

module ActiveRecord
  class ForeignKeyConstraint
    ACTIONS = { :restrict => 'RESTRICT', :no_action   => 'NO ACTION', :cascade  => 'CASCADE',
                :set_null => 'SET NULL', :set_default => 'SET DEFAULT' }.freeze
                
    attr_accessor :name, :referenced_table
    attr_reader :key, :referenced_key, :update_action, :delete_action
    
    def initialize(name, key, referenced_table, referenced_key, update_action = nil, delete_action = nil)
      self.name = name
      self.key = key
      self.referenced_table = referenced_table
      self.referenced_key = referenced_key
      self.update_action = update_action
      self.delete_action = delete_action
    end
    
    def key=(columns)
      @key = columns.is_a?(Enumerable) && columns.length == 1 ? columns.first : columns
    end
    
    def referenced_key=(columns)
      @referenced_key = columns.is_a?(Enumerable) && columns.length == 1 ? columns.first : columns
    end
    
    def update_action=(action)
      @update_action = ACTIONS.invert[action] || action || :restrict
    end
    
    def delete_action=(action)
      @delete_action = ACTIONS.invert[action] || action || :restrict
    end
    
    def ==(other)
      name == other.name && key == other.key &&
      referenced_table == other.referenced_table && referenced_key == other.referenced_key &&
      update_action == other.update_action && delete_action == other.delete_action
    end
    
    def quote_constraint_action(action)
      ACTIONS[action.to_sym] || action.to_s
    end
    
    def to_sql(connection)
      (name.blank? ? "" : "CONSTRAINT #{connection.quote_column_name(name)} ") +
      "FOREIGN KEY (#{connection.quote_column_names(key)}) " +
      "REFERENCES #{connection.quote_table_name(referenced_table)} (#{connection.quote_column_names(referenced_key)}) " +
      "ON UPDATE #{quote_constraint_action(update_action)} " +
      "ON DELETE #{quote_constraint_action(delete_action)}"
    end
    
    def to_dump
      dump = "#{key.inspect}, #{referenced_table.inspect}, #{referenced_key.inspect}"
      dump << ", :name => #{name.inspect}" unless name.blank?
      dump << ", :on_update => #{update_action.inspect}" if update_action != :restrict
      dump << ", :on_delete => #{delete_action.inspect}" if delete_action != :restrict
      dump
    end
    
    def to_s
      name
    end
    
    def self.constraint_action_from_sql(action)
      ACTIONS.invert[action] || action
    end
  end
  
  module ConnectionAdapters
    module SchemaStatements
      VALID_FOREIGN_KEY_OPTIONS = [:name, :on_update, :on_delete]
      
      def add_foreign_key_constraint(table_name, key, referenced_table, referenced_key, options = {})
        options.assert_valid_keys(VALID_FOREIGN_KEY_OPTIONS)
        execute "ALTER TABLE #{quote_table_name(table_name)} ADD #{ForeignKeyConstraint.new(options[:name], key, referenced_table, referenced_key, options[:on_update], options[:on_delete]).to_sql(self)}"
      end
      
      def remove_foreign_key_constraint(table_name, constraint)
        execute "ALTER TABLE #{quote_table_name(table_name)} DROP CONSTRAINT #{quote_column_name(constraint)}"
      end
    end
    
    class AbstractAdapter
      def quote_column_names(*column_names)
        column_names.flatten.map {|column_name| quote_column_name(column_name)} * ', '
      end
      
      def drop_table_with_foreign_keys(table_name, options = {})
        remove_foreign_key_constraints_referencing(table_name) if tables.include?(table_name) # the if is an optimization for the sake of create_table with :force => true, which is crucial for db:test:prepare performance on mysql as mysql's INFORMATION_SCHEMA implementation is excrutiatingly slow; it's not needed for postgres, but does give a small boost to performance there too
        drop_table_without_foreign_keys(table_name, options)
      end
      alias_method_chain :drop_table, :foreign_keys
    end
    
    module MysqlAdapterForeignKeyMethods # common to mysql & mysql2
      def remove_foreign_key_constraint(table_name, constraint)
        execute "ALTER TABLE #{quote_table_name(table_name)} DROP FOREIGN KEY #{quote_column_name(constraint)}"
      end
    
      def remove_foreign_key_constraints_referencing(table_name)
        select_rows(
                "SELECT DISTINCT TABLE_NAME, CONSTRAINT_NAME" +
                "  FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE" +
                " WHERE REFERENCED_TABLE_SCHEMA = SCHEMA()" +
                "   AND REFERENCED_TABLE_NAME = #{quote(table_name)}").each do |table_name, constraint_name|
          remove_foreign_key_constraint(table_name, constraint_name)
        end
      end
    
      def foreign_key_constraints_on(table_name)
        self.class.constraints_from_sql(select_one("SHOW CREATE TABLE #{quote_table_name(table_name)}")["Create Table"])
      end
      
      def self.constraints_from_sql(create_table_sql)
        # the clauses look like this: CONSTRAINT `ab` FOREIGN KEY (`ac`, `bc`) REFERENCES `parent` (`a`, `b`) ON DELETE SET NULL ON UPDATE CASCADE
        create_table_sql.scan(/CONSTRAINT `([^`]+)` FOREIGN KEY \((`(?:[^`]+)`(?:, `(?:[^`]+)`)*)\) REFERENCES `([^`]+)` \((`(?:[^`]+)`(?:, `(?:[^`]+)`)*)\)(?: ON DELETE (CASCADE|RESTRICT|NO ACTION|SET NULL|SET DEFAULT))?(?: ON UPDATE (CASCADE|RESTRICT|NO ACTION|SET NULL|SET DEFAULT))?/).collect do |capture|
          ForeignKeyConstraint.new(capture[0], columns_from_sql(capture[1]), capture[2], columns_from_sql(capture[3]), capture[5], capture[4])
        end
      end
  
      def self.columns_from_sql(column_list_sql)
        column_list_sql.scan(/`([^`]+)`/).collect(&:first)
      end
    end
    
    if const_defined?(:MysqlAdapter)
      class MysqlAdapter
        include MysqlAdapterForeignKeyMethods
      
        def self.constraints_from_sql(create_table_sql)
          MysqlAdapterForeignKeyMethods.constraints_from_sql(create_table_sql)
        end
      
        def self.columns_from_sql(column_list_sql)
          MysqlAdapterForeignKeyMethods.columns_from_sql(column_list_sql)
        end
      end
    end
    
    if const_defined?(:Mysql2Adapter)
      class Mysql2Adapter
        include MysqlAdapterForeignKeyMethods
      
        def self.constraints_from_sql(create_table_sql)
          MysqlAdapterForeignKeyMethods.constraints_from_sql(create_table_sql)
        end
      
        def self.columns_from_sql(column_list_sql)
          MysqlAdapterForeignKeyMethods.columns_from_sql(column_list_sql)
        end
      end
    end
    
    if const_defined?(:PostgreSQLAdapter)
      class PostgreSQLAdapter
        def remove_foreign_key_constraints_referencing(table_name)
          select_rows(
                  "SELECT referenced.relname, pg_constraint.conname" +
                  "  FROM pg_constraint, pg_class, pg_class referenced" +
                  " WHERE pg_constraint.confrelid = pg_class.oid" +
                  "   AND pg_class.relname = #{quote(table_name)}" +
                  "   AND referenced.oid = pg_constraint.conrelid").each do |table_name, constraint_name|
            remove_foreign_key_constraint(table_name, constraint_name)
          end
        end
      
        def foreign_key_constraints_on(table_name)
          select_rows(
                  "SELECT pg_constraint.conname, pg_get_constraintdef(pg_constraint.oid)" +
                  "  FROM pg_constraint, pg_class" +
                  " WHERE pg_constraint.conrelid = pg_class.oid" +
                  "   AND pg_class.relname = #{quote(table_name)}").collect do |name, constraintdef|
            self.class.foreign_key_from_sql(name, constraintdef)
          end.compact
        end
      
        def self.foreign_key_from_sql(name, foreign_key_sql)
          # the clauses look like this: FOREIGN KEY (ac, bc) REFERENCES parent(ap, bp) ON UPDATE CASCADE ON DELETE SET NULL
          capture = foreign_key_sql.match(/FOREIGN KEY \(((?:\w+)(?:, \w+)*)\) REFERENCES (\w+)\(((?:\w+)(?:, \w+)*)\)(?: ON UPDATE (CASCADE|RESTRICT|NO ACTION|SET NULL|SET DEFAULT))?(?: ON DELETE (CASCADE|RESTRICT|NO ACTION|SET NULL|SET DEFAULT))?/)
          ForeignKeyConstraint.new(name, capture[1].split(', '), capture[2], capture[3].split(', '), capture[4], capture[5]) if capture
        end
      end
    end
  end

  class SchemaDumper
    def foreign_key_constraints_on(table_name, stream)
      constraints = @connection.foreign_key_constraints_on(table_name)
      constraints.each {|constraint| stream.puts "  add_foreign_key_constraint #{table_name.inspect}, #{constraint.to_dump}"}
      stream.puts unless constraints.empty?
    end

    def tables_with_foreign_key_constraints(stream)
      tables_without_foreign_key_constraints(stream)
      @connection.tables.sort.each {|table| foreign_key_constraints_on(table, stream)}
    end
    
    alias_method_chain :tables, :foreign_key_constraints
  end
end
