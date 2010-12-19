require File.expand_path('test_helper', File.dirname(__FILE__))

class AttachmentPathCacheWithHostIdTest < ActiveSupport::TestCase

  load_schema! 'schema.rb'
  setup :clear_images_dir
  setup do
    # will use the host name by default :
    AttachmentFx::Owner::PathCache.host_id = false
  end

  require File.expand_path('attachment_path_cache_test_impl', File.dirname(__FILE__))
  include AttachmentPathCacheTestImpl

end
