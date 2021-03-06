require File.expand_path('test_helper', File.dirname(__FILE__))

class AttachmentPathCacheTest < ActiveSupport::TestCase

  load_schema! 'schema.rb'
  setup :clear_images_dir
  setup do
    AttachmentFx::Owner::PathCache.host_id = nil # host_id won't be used
  end

  require File.expand_path('attachment_path_cache_test_impl', File.dirname(__FILE__))
  include AttachmentPathCacheTestImpl

end
