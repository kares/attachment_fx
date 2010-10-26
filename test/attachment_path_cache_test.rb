require File.expand_path('test_helper', File.dirname(__FILE__))

class AttachmentPathCacheTest < ActiveSupport::TestCase

  # NOTE: due to Rails 2.3.x :
  # ActiveRecord::StatementInvalid: Mysql::Error: SAVEPOINT active_record_1 does not exist:
  # ROLLBACK TO SAVEPOINT active_record_1
  #  app/models/attachment_file.rb:88:in `save'
  #  test/unit/attachment_file_test.rb:204:in `test_validates_as_attachment_and_reports_errors_on'
  #
  # http://rails.lighthouseapp.com/projects/8994/tickets/1925-mysqlerror-savepoint-active_record_1-does-not-exist-rollback-to-savepoint-active_record_1
  #self.use_transactional_fixtures = false

  TEST_FILES_PATH = File.join(File.dirname(__FILE__), 'files')

  TEST_IMAGE_PATH_PREFIX = 'public/files/images'

  load_schema! 'schema.rb'
  setup :clear_images_dir

  class ::AttachmentFile < ActiveRecord::Base
    has_attachment :storage => :db_file,
                   :processor => :mini_magick
  end

  class ::Image < AttachmentFile

    has_attachment :content_type => :image,
                   :path_prefix => TEST_IMAGE_PATH_PREFIX,
                   :resize_to => '192x192>', # resize to no wider than 192px
                   :thumbnail_class => self, # store thumbnails with parent
                   :thumbnails => { :half => '96x96>' }

  end

  class ::ImageOwnerWithPathCache < ActiveRecord::Base

    set_table_name 'image_owners_with_path_cache'

    has_attachment_file :image, :class_name => 'Image'

  end

  # copied from AttachmentFileTest :

  test 'owner instance responds_to attachment name method' do
    assert ImageOwnerWithPathCache.new.respond_to? :image
  end

  test 'owner instance responds_to attachment helper methods' do
    assert ImageOwnerWithPathCache.new.respond_to? :has_image?
    assert ImageOwnerWithPathCache.new.respond_to? :image_path
  end

  test 'owner has attachment returns true only if attachment is persisted' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    owner = ImageOwnerWithPathCache.new

    assert ! owner.has_image?
    owner.image = image
    assert ! owner.has_image?
    
    image.save
    assert owner.has_image?
  end

  test 'owner has attachment after it has been created' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image_data = AttachmentFile.file_as_uploaded_data(file)
    owner = ImageOwnerWithPathCache.new

    assert ! owner.has_image?
    assert owner.create_image(:uploaded_data => image_data)
    assert owner.has_image?
  end

  test 'owner returns attachment path only if attachment is persisted' do
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

  test 'owner caches attachment_path when attachment is created' do
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache.create!(:image => { :uploaded_data => file_data })
    owner = ImageOwnerWithPathCache.find(owner.id)
    assert_not_blank owner[:attachment_path_cache]
    assert ! owner.loaded_image?

    owner.image_path
    assert ! owner.loaded_image?
  end

  test 'owner caches attachment_path for thumbnail when attachment is created' do
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache.create!(:image => { :uploaded_data => file_data })
    owner = ImageOwnerWithPathCache.find(owner.id)
    assert_not_blank owner[:attachment_path_cache]
    assert ! owner.loaded_image?

    owner.image_path(:half)
    assert ! owner.loaded_image?
  end

  test 'owner caches attachment_path method result and does not load association second time' do
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

  test 'attachment owner should return the same owner instance' do
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache.create!(:image => { :uploaded_data => file_data }).reload
    assert_equal owner, owner.image.owner
  end

  test 'owner removes cached attachment_path after attachment is destoyed' do
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache.create!(:image => { :uploaded_data => file_data })
    owner = ImageOwnerWithPathCache.find(owner.id)
    assert_not_blank owner[:attachment_path_cache]
    #puts "destoying image !"
    owner.image.destroy
    #puts "destoying image owner #{owner} #{owner.attachment_path_cache.inspect}"

    #assert_blank owner.image_path # NOTE works only after reload !
    assert_blank owner.reload.image_path
  end

  test 'owner reports not having attachment after attachment is destoyed' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image_data = AttachmentFile.file_as_uploaded_data(file)
    owner = ImageOwnerWithPathCache.create!

    assert owner.create_image(:uploaded_data => image_data)
    assert owner.has_image?

    owner.image.destroy
    #assert ! owner.has_image? # NOTE works only after reload !
    assert ! owner.reload.has_image?
  end

  class ::Image2 < AttachmentFile

    has_attachment # TODO need to call even if no new option

  end

  class ::ImageOwnerWithPathCache2 < ActiveRecord::Base

    set_table_name 'image_owners_with_path_cache'

    has_attachment_file :image1, :class_name => 'Image'
    has_attachment_file :image2

  end

  test 'owner has_attachment? with 2 attachments' do
    file_data1 = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache2.new(:image1 => { :uploaded_data => file_data1 })
    #puts "0: #{owner} " + owner.attachment_path_cache.inspect + "\n\n"
    owner.save!
    #puts "1: #{owner} " + owner.attachment_path_cache.inspect + "\n\n"
    assert owner.has_image1?
    assert ! owner.has_image2?
    #puts owner.inspect
    #puts "2: #{owner} " + owner.attachment_path_cache.inspect + "\n\n"
    owner.reload
    #puts owner.inspect
    #puts '3: ' + owner.attachment_path_cache.inspect + "\n\n"
    assert owner.has_image1?
    
    assert ! owner.has_image2?
    
    owner = ImageOwnerWithPathCache2.find(owner.id)
    assert owner.has_image1?
    assert ! owner.has_image2?
  end

  test 'owner attachment_path with 2 attachments' do
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
  test 'owner update_attachment_path_cache without args updates cache for all attachments' do
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

  test 'owner update_attachment_path_cache works if record is readonly' do
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    owner = ImageOwnerWithPathCache.create!(:image => { :uploaded_data => file_data })
    image_path = owner.image_path
    owner.update_attribute(:attachment_path_cache, nil)
    owner = ImageOwnerWithPathCache.find(owner.id)
    owner.readonly!
    owner.send :update_attachment_path_cache

    assert owner.has_image?
    assert_equal image_path, owner.image_path
    assert owner.loaded_image?
  end

  test 'owner update_attachment_path_cache works if record is readonly 2' do
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

  private

    def clear_images_dir
      images_dir = File.join File.dirname(__FILE__), TEST_IMAGE_PATH_PREFIX
      FileUtils.rm_f(images_dir) if File.exist?(images_dir)
      FileUtils.mkdir_p images_dir
    end

end
