
require 'rubygems' rescue nil

require 'logger'
require 'test/unit'
require 'mocha'

# a minimal Rails ENV :
require File.expand_path(File.join(File.dirname(__FILE__), 'rails_setup'))

SCHEMA_BASE = File.dirname(__FILE__)

$LOAD_PATH << File.expand_path( File.dirname(__FILE__) + '/../lib' )
$LOAD_PATH << File.expand_path( File.dirname(__FILE__) + '/attachment_fu/lib' )

# setup attachment_fu as a _plugin_ :
require 'geometry'
require 'technoweenie/attachment_fu'
require 'technoweenie/attachment_fu/backends/db_file_backend'
require 'technoweenie/attachment_fu/backends/file_system_backend'
require 'technoweenie/attachment_fu/processors/mini_magick_processor'
load File.expand_path( File.dirname(__FILE__) + '/attachment_fu/init.rb' )

require 'attachment_fx'

ActiveSupport::TestCase.class_eval do

  def self.load_schema! schema_file
    ActiveRecord::Migration.verbose = false # quiet down the migration engine
    ActiveRecord::Base.configurations = { 'test' => {
      'adapter' => 'sqlite3', 'database' => ':memory:'
    }}
    ActiveRecord::Base.establish_connection('test')
    ActiveRecord::Base.silence do
      load File.join(SCHEMA_BASE, schema_file)
    end
  end

  def assert_blank(object, message="")
    full_message = build_message(message, "<?> expected to be blank.", object)
    assert_block(full_message){ object.blank? }
  end

  def assert_not_blank(object, message="")
    full_message = build_message(message, "<?> expected to not be blank.", object)
    assert_block(full_message){ ! object.blank? }
  end

  protected

    def load_schema! schema_file
      self.class.load_schema! schema_file
    end

    def create_table(class_or_name, options = {}, &block)
      table_name = if class_or_name.respond_to?(:table_name)
        class_or_name.table_name
      else
        class_or_name
      end
      block = lambda { |table| table } unless block
      options = options.reverse_merge(:force => true, :temporary => nil)

      connection = ActiveRecord::Base.connection
      if connection.table_exists?(table_name)
        if class_or_name.respond_to?(:destroy_all)
          class_or_name.destroy_all
        else
          connection.execute("DELETE FROM #{table_name} WHERE 0 = 0")
        end
      end

      result = connection.create_table(table_name, options, &block)

      if class_or_name.respond_to?(:reset_column_information)
        class_or_name.reset_column_information
      end

      result
    end

end
