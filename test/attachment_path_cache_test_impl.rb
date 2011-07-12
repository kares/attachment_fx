
module AttachmentPathCacheTestImpl

  TEST_FILES_PATH = File.join(File.dirname(__FILE__), 'files')

  TEST_IMAGE_PATH_PREFIX = 'public/files/images'

  class AttachmentFile < ActiveRecord::Base
    set_table_name 'attachment_files'

    has_attachment :storage => :db_file,
                   :processor => :mini_magick
  end

  class Image < AttachmentFile

    has_attachment :content_type => :image,
                   :path_prefix => TEST_IMAGE_PATH_PREFIX,
                   :resize_to => '192x192>', # resize to no wider than 192px
                   :thumbnail_class => self, # store thumb-nails with parent
                   :thumbnails => { :half => '96x96>' }

  end

  class ImageOwnerWithPathCache < ActiveRecord::Base

    set_table_name 'image_owners_with_path_cache'

    has_attachment_file :image, :class_name => 'Image'

  end

  def test_owner_instance_responds_to_attachment_name_method
    assert ImageOwnerWithPathCache.new.respond_to? :image
  end

  def test_owner_instance_responds_to_attachment_helper_methods
    assert ImageOwnerWithPathCache.new.respond_to? :has_image?
    assert ImageOwnerWithPathCache.new.respond_to? :image_path
  end

  def test_owner_has_attachment_returns_true_only_if_attachment_is_persisted
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    owner = ImageOwnerWithPathCache.new

    assert ! owner.has_image?
    owner.image = image
    assert ! owner.has_image?

    image.save
    assert owner.has_image?
  end

  def test_owner_has_attachment_after_it_has_been_created
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image_data = AttachmentFile.file_as_uploaded_data(file)
    owner = ImageOwnerWithPathCache.new

    assert ! owner.has_image?
    assert owner.create_image(:uploaded_data => image_data)
    assert owner.has_image?
  end

  def test_owner_returns_attachment_path_only_if_attachment_is_persisted
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    owner = ImageOwnerWithPathCache.new

    assert_blank owner.image_path
    owner.image = image
    assert_blank owner.image_path

    image.save
    assert_not_blank owner.image_path
  end

  #

  def test_owner_caches_attachment_path_when_attachment_is_created
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache.create!(:image => { :uploaded_data => file_data })
    owner = ImageOwnerWithPathCache.find(owner.id)
    assert_not_blank owner[:attachment_path_cache]
    assert ! owner.loaded_image?

    owner.image_path
    assert ! owner.loaded_image?
  end

  def test_owner_caches_attachment_path_for_thumbnail_when_attachment_is_created
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache.create!(:image => { :uploaded_data => file_data })
    owner = ImageOwnerWithPathCache.find(owner.id)
    assert_not_blank owner[:attachment_path_cache]
    assert ! owner.loaded_image?

    owner.image_path(:half)
    assert ! owner.loaded_image?
  end

  def test_owner_caches_attachment_path_method_result_and_does_not_load_association_second_time
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache.create!(:image => { :uploaded_data => file_data })
    owner.update_attribute(:attachment_path_cache, nil)
    owner = ImageOwnerWithPathCache.find(owner.id)

    assert ! owner.loaded_image?

    image_path = owner.image_path
    assert owner.loaded_image?

    owner = ImageOwnerWithPathCache.find(owner.id)
    assert ! owner.loaded_image?

    assert_equal image_path, owner.image_path
    assert ! owner.loaded_image?
  end

  def test_attachment_owner_should_return_the_same_owner_instance
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache.create!(:image => { :uploaded_data => file_data }).reload
    assert_equal owner, owner.image.owner
  end

  def test_owner_removes_cached_attachment_path_after_attachment_is_destoyed
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache.create!(:image => { :uploaded_data => file_data })
    owner = ImageOwnerWithPathCache.find(owner.id)
    assert_not_blank owner[:attachment_path_cache]
    owner.image.destroy

    assert_blank owner.image_path # NOTE works only after reload for < 2.3.6
    assert_blank owner.reload.image_path
  end

  def test_owner_reports_not_having_attachment_after_attachment_is_destoyed
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image_data = AttachmentFile.file_as_uploaded_data(file)
    owner = ImageOwnerWithPathCache.create!

    assert owner.create_image(:uploaded_data => image_data)
    assert owner.has_image?

    owner.image.destroy
    assert ! owner.has_image? # NOTE works only after reload for < 2.3.6
    assert ! owner.reload.has_image?
  end

  def test_owner_attachment_path_cache_is_correctly_updated_after_adding_and_removing_an_attachment
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache.create!(:name => 'Ujo Jebo', :image => { :uploaded_data => file_data })
    assert_equal 'Ujo Jebo', owner.name
    assert_not_blank owner[:attachment_path_cache]
    assert owner.has_image?
    assert_not_blank owner.reload[:attachment_path_cache]

    owner.image.destroy
    assert_not_blank owner[:attachment_path_cache]
    assert_blank owner.image_path
    owner.reload
    assert_blank owner.image_path

    owner.update_attributes(:name => 'Stryko Jebo', :image => { :uploaded_data => file_data })
    assert_equal 'Stryko Jebo', owner.name
    assert_not_blank owner[:attachment_path_cache]
    assert owner.has_image?
    assert_not_blank owner.reload[:attachment_path_cache]
    assert_not_blank owner.image_path
  end

  def test_owner_attachment_path_cache_is_correctly_updated_after_adding_an_attachment_twice
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache.create!(:name => 'Ujo Jebo', :image => { :uploaded_data => file_data })
    assert_equal 'Ujo Jebo', owner.name
    assert_not_nil owner[:attachment_path_cache]
    assert owner.has_image?
    assert_not_nil owner.reload[:attachment_path_cache]

    old_image = owner.image

    owner.update_attributes(:name => 'Stryko Jebo', :image => { :uploaded_data => file_data })
    assert_equal 'Stryko Jebo', owner.name
    assert_not_nil owner[:attachment_path_cache]
    assert owner.has_image?
    assert_not_equal old_image, owner.image
    assert_not_nil owner.reload[:attachment_path_cache]
    assert_not_blank owner.image_path
  end

  class ImageOwnerWithPathCache2 < ActiveRecord::Base

    set_table_name 'image_owners_with_path_cache'

    has_attachment_file :image1, :class_name => 'Image'

    class Image2 < AttachmentFile

      has_attachment # NOTE: need to call even if no new option

    end

    has_attachment_file :image2

  end

  def test_owner_has_attachment_with_2_attachments
    file_data1 = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache2.new(:image1 => { :uploaded_data => file_data1 })
    owner.save!
    assert owner.has_image1?
    assert ! owner.has_image2?
    owner.reload
    assert owner.has_image1?

    assert ! owner.has_image2?

    owner = ImageOwnerWithPathCache2.find(owner.id)
    assert owner.has_image1?
    assert ! owner.has_image2?
  end

  def test_owner_attachment_path_with_2_attachments
    file_data1 = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache2.create! :image1 => { :uploaded_data => file_data1 }
    assert_not_blank owner.image1_path
    assert_blank owner.image2_path

    owner.reload
    assert_not_blank owner.image1_path
    assert_blank owner.image2_path

    owner = ImageOwnerWithPathCache2.find(owner.id)
    assert_not_blank owner.image1_path
    assert_blank owner.image2_path
  end

  # TODO this test fails if Image2 does not call has_attachment !
  def test_owner_update_attachment_path_cache_without_args_updates_cache_for_all_attachments
    file_data1 = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    file_data2 = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.png'
    owner = ImageOwnerWithPathCache2.create!(:image1 => { :uploaded_data => file_data1 },
                                             :image2 => { :uploaded_data => file_data2 })
    owner.update_attribute(:attachment_path_cache, nil)
    owner.send :update_attachment_path_cache

    owner = ImageOwnerWithPathCache2.find(owner.id)
    assert owner.has_image1?
    assert owner.has_image2?
    assert_not_blank owner.image1_path
    assert_not_blank owner.image2_path
    assert ! owner.loaded_image1?
    assert ! owner.loaded_image2?
  end

  def test_owner_update_attachment_path_cache_works_if_record_is_readonly_1
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache.create!(:image => { :uploaded_data => file_data })
    image_path = owner.image_path
    owner.update_attribute(:attachment_path_cache, nil)
    owner = ImageOwnerWithPathCache.find(owner.id)
    owner.readonly!
    assert_equal false, owner.send(:update_attachment_path_cache)

    assert owner.has_image?
    assert_equal image_path, owner.image_path
    assert owner.loaded_image?
    
    path_cache = owner.attachment_path_cache
    owner = ImageOwnerWithPathCache.find(owner.id)
    owner.update_attribute(:attachment_path_cache, path_cache)
    owner.readonly!
    assert_equal nil, owner.send(:update_attachment_path_cache) # no update necessary
  end

  def test_owner_update_attachment_path_cache_works_if_record_is_readonly_2
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache.create!(:image => { :uploaded_data => file_data })
    owner.update_attribute(:attachment_path_cache, nil)
    owner = ImageOwnerWithPathCache.find(owner.id)
    image_path = owner.image_path
    assert owner.loaded_image?

    owner = ImageOwnerWithPathCache.find(owner.id)
    owner.readonly!
    assert ! owner.loaded_image?

    assert_equal image_path, owner.image_path
    assert ! owner.loaded_image?
  end

  def test_update_attachment_path_cache_updates_if_path_not_yet_cached
    file_data1 = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache2.create! :image1 => { :uploaded_data => file_data1 }
    # owner.expects(:update_attachment_path_cache_attribute).once :
    def owner.store_attachment_path_cache(value)
      @store_attachment_path_cache ||= 0
      @store_attachment_path_cache += 1
    end
    owner.send(:update_attachment_path_cache)
    assert_equal 1, owner.instance_variable_get(:@store_attachment_path_cache)
  end

  def test_update_attachment_path_cache_does_not_update_if_path_cached
    file_data1 = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache2.create! :image1 => { :uploaded_data => file_data1 }
    owner.send(:update_attachment_path_cache)
    # owner.expects(:update_attachment_path_cache_attribute).never :
    def owner.store_attachment_path_cache(value)
      raise "store_attachment_path_cache(#{value.inspect}) : not expected to be invoked !"
    end
    owner.send(:update_attachment_path_cache)
  end

  def test_owner_expire_attachment_path_cache_sets_and_updates_path_cache_to_nil
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache.create!(:image => { :uploaded_data => file_data })
    owner = ImageOwnerWithPathCache.find(owner.id)
    owner.reload
    assert_not_nil owner.attachment_path_cache
    #attachment_path_cache = owner.attachment_path_cache
    attachment_path_cache = owner.send :fetch_attachment_path_cache
    assert attachment_path_cache.has_key?('image')
    assert_not_nil attachment_path_cache['image']

    owner.expire_attachment_path_cache
    #attachment_path_cache = owner.attachment_path_cache
    attachment_path_cache = owner.send :fetch_attachment_path_cache
    assert_blank attachment_path_cache
    owner.reload
    attachment_path_cache = owner.send :fetch_attachment_path_cache
    assert_blank attachment_path_cache
  end

  private

    def clear_images_dir
      images_dir = File.join File.dirname(__FILE__), TEST_IMAGE_PATH_PREFIX
      FileUtils.rm_f(images_dir) if File.exist?(images_dir)
      FileUtils.mkdir_p images_dir
    end

end
