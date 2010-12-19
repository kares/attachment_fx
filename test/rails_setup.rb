# emulates a minimal Rails environment for tests

# enable testing with different version of rails via argv :
# ruby request_exception_handler_test.rb RAILS_VERSION=2.3.5

version =
  if ARGV.find { |opt| /RAILS_VERSION=([\d\.]+)/ =~ opt }
    $~[1]
  else
    # rake test RAILS_VERSION=2.3.8
    ENV['RAILS_VERSION']
  end

if version
  gem 'activesupport', "= #{version}"
  gem 'activerecord', "= #{version}"
  gem 'actionpack', "= #{version}"
  gem 'actionmailer', "= #{version}"
  gem 'rails', "= #{version}"
else
  gem 'activesupport'
  gem 'activerecord'
  gem 'actionpack'
  gem 'actionmailer'
  gem 'rails'
end

require 'rails/version'
puts "emulating Rails.version = #{Rails::VERSION::STRING}"

require 'active_support'
require 'active_support/all'
require 'active_support/test_case'
require 'active_record'
require 'active_record/base'

require 'action_pack'
if ActionPack::VERSION::MAJOR >= 3
  require 'action_dispatch/http/mime_type'
else
  require 'action_controller/mime_type'
end

require 'active_support/core_ext/kernel/reporting'

silence_warnings { RAILS_ENV = "test" }
silence_warnings { RAILS_ROOT = File.expand_path(File.dirname(__FILE__)) } # should be absolute !
silence_warnings { RAILS_DEFAULT_LOGGER = Logger.new("#{RAILS_ROOT}/test.log") }
ActiveRecord::Base.logger = RAILS_DEFAULT_LOGGER

#$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '../lib')
