require File.expand_path('test_helper', File.dirname(__FILE__))

class AttachmentFileTest < ActiveSupport::TestCase

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

  begin
    require 'mime/types'

    test 'content_type resolves from MIME::Types if available' do
      type = [ MIME::Type.from_array('some/xxx-mime', ['xxx']) ]
      MIME::Types.expects(:type_for).with('dir/filename.xxx').returns(type)
      assert_equal 'some/xxx-mime', AttachmentFile.content_type_for('dir/filename.xxx')
    end

    test 'correct content_type is returned with MIME::Types' do
      assert_equal 'text/html', AttachmentFile.content_type_for('dir/filename.html')
    end

  rescue
    puts "mime-types gem not available skipping related tests"
  end

  test 'content_type resolves from Rails built-in Mime::Type' do
    begin
      mime_const = Object.send(:remove_const, :MIME) if defined?(MIME::Types)
      
      Mime::Type.expects(:lookup_by_extension).with('jpg').returns('image/jpeg')
      assert_equal 'image/jpeg', AttachmentFile.content_type_for('dir/filename.jpg')
    ensure
      Object.const_set(:MIME, mime_const) if mime_const
    end
  end

  test 'correct content_type is returned with Mime::Type' do
    begin
      mime_const = Object.send(:remove_const, :MIME) if defined?(MIME::Types)

      assert_equal 'text/html', AttachmentFile.content_type_for('dir/filename.html')
    ensure
      Object.const_set(:MIME, mime_const) if mime_const
    end
  end

  class AttachmentFile < ActiveRecord::Base
    set_table_name 'attachment_files'
    has_attachment :storage => :db_file,
                   :processor => :mini_magick
  end

  class Image < AttachmentFile

    has_attachment :storage => :db_file,
                   :content_type => :image,
                   :path_prefix => TEST_IMAGE_PATH_PREFIX,
                   :resize_to => '192x192>', # not wider than 192 pixels
                   :thumbnail_class => self, # store thumb-nails with parent
                   :thumbnails => { :half => '96x96>' }

  end

  class ImageOwner < ActiveRecord::Base
    set_table_name 'image_owners'

    has_attachment_file :image, :class_name => 'Image'

  end

  test 'AttachmentFile subclass responds_to new_from_file' do
    assert Image.respond_to? :new_from_file
  end

  test 'AttachmentFile subclass new_from_file returns instance' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    assert_not_nil image = Image.new_from_file(file)
    assert_kind_of Image, image
  end

  test 'AttachmentFile new_from_file instance saves' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    assert image.save, "save failed: #{image.errors.inspect}"
  end

  test 'Image saved instance creates 2 AttachmentFile-s' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    assert_difference 'AttachmentFile.count', +2 do
      image.save
    end
  end

  test 'Image saved instance creates 2 DbFile-s' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    assert_difference 'DbFile.count', +2 do
      image.save
    end
  end

  test 'Image.count does include thumbnails' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    assert_difference 'Image.count', +2 do
      image.save
    end
  end

  class OtherImage < AttachmentFile

    class ThumbnailImage < AttachmentFile

    end

    has_attachment :storage => :db_file,
                   :content_type => :image,
                   :path_prefix => TEST_IMAGE_PATH_PREFIX,
                   :thumbnail_class => ThumbnailImage,
                   :thumbnails => { :some => '96x96' }

  end

  test 'Image.count does not include OtherImage-s' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    other_image = OtherImage.new_from_file(file)
    assert_difference 'Image.count', +2 do
      image.save
      assert other_image.save
    end
  end

  test 'OtherImage.count does not include thumbnails of different type' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    other_image = OtherImage.new_from_file(file)
    assert_difference 'OtherImage.count', +1 do
      assert_difference 'AttachmentFile.count', +2 do
        assert other_image.save
      end
    end
  end

  class OtherImage2 < AttachmentFile

    class ThumbnailImage < OtherImage2
    end

    has_attachment :storage => :db_file,
                   :content_type => :image,
                   :path_prefix => TEST_IMAGE_PATH_PREFIX,
                   :thumbnail_class => ThumbnailImage,
                   :thumbnails => { :t1 => '96x96', :t2 => '48x48' }

  end

  test 'OtherImage2.count does include thumbnails of inherited type' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    other_image2 = OtherImage2.new_from_file(file)
    assert_difference 'OtherImage2.count', +3 do
      assert_difference 'OtherImage2::ThumbnailImage.count', +2 do
        assert other_image2.save
      end
    end
  end

  test 'Image has :half thumbnail' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    image.save
    assert_nothing_raised do
      assert_equal true, image.has_thumbnail?(:half)
    end
  end

  test 'Image does not have :small thumbnail' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    image.save
    assert_nothing_raised do
      assert_equal false, image.has_thumbnail?(:small)
    end
  end

  test 'Image thumbnail is of same kind' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    image.save
    assert_nothing_raised do
      assert_not_nil test_thumb = image.find_thumbnail(:half)
      assert_kind_of Image, test_thumb
    end
  end

  test 'owner instance responds_to attachment name method' do
    assert ImageOwner.new.respond_to? :image
  end

  test 'owner instance responds_to attachment helper methods' do
    assert ImageOwner.new.respond_to? :has_image?
    assert ImageOwner.new.respond_to? :image_path
  end

  test 'owner has attachment returns true only if attachment is persisted' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    owner = ImageOwner.new

    assert ! owner.has_image?
    owner.image = image
    assert ! owner.has_image?
    
    image.save
    assert owner.has_image?
  end

  test 'owner returns attachment path only if attachment is persisted' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    owner = ImageOwner.new

    assert_blank owner.image_path
    owner.image = image
    assert_blank owner.image_path

    image.save
    assert_not_blank owner.image_path
  end

  test 'Image (:storage => :db_file) has a filename interface' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    assert image.respond_to? :full_filename
    assert image.respond_to? :public_filename
  end

  test 'Image full_filename returns if saved' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    image.save

    assert_nothing_raised do
      assert_not_nil image.full_filename
    end
  end

  test 'Image full_filename raises error if not yet saved' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    
    assert_raise ActiveRecord::ActiveRecordError do
      image.full_filename
    end
  end

  test 'Image full_filename returns valid file path' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    image.save

    assert_nothing_raised do
      assert File.exist?(image.full_filename), "#{image.full_filename} does not exist !"
    end
  end

  test 'Image full_filename for thumbnail returns valid file path' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    image.save

    assert File.exist?(image.full_filename(:half)), "#{image.full_filename} does not exist !"
  end

  test 'Image full_filename path is under the configured path_prefix' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    image.save
    
    path_prefix = File.expand_path(TEST_IMAGE_PATH_PREFIX, RAILS_ROOT)
    assert image.full_filename.starts_with?(path_prefix), "#{image.full_filename} does not start with: #{path_prefix}"
  end

  test 'Image full_filename returns the original basename' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
    image = Image.new_from_file(file)
    image.save

    test_basename = File.basename(image.full_filename)
    assert_equal File.basename(file), test_basename
  end

  test 'Image destory deletes (cached) file from filesystem' do
    file = File.join(TEST_FILES_PATH, 'attachment_file_test.png')
    image = Image.new_from_file(file)
    image.save

    assert File.exist?(filename = image.full_filename)
    dirname = File.dirname(image.full_filename)

    image.destroy
    assert ! Image.exists?(image.id)
    assert ! File.exist?(filename)
    # it even removes the directory :
    assert ! File.exist?(dirname)
  end

  test 'attachment gest created on uploaded_data assignment' do
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.pdf'

    image_owner = ImageOwner.new(:image => { :uploaded_data => file_data })
    assert_not_nil image_owner.image
    assert_instance_of Image, image_owner.image
    assert_equal 'attachment_file_test.pdf', image_owner.image.filename
  end

  test 'attachment gets saved with owner on create' do
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'

    image_owner = ImageOwner.new(:image => { :uploaded_data => file_data })
    assert_nil image_owner.image.id
    assert image_owner.save
    assert_not_nil image_owner.image.id
  end

  test 'attachment gets created with owner on update' do
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    image_owner = ImageOwner.create!

    assert image_owner.update_attributes(:name => 'jupii', :image => { :uploaded_data => file_data })

    assert_equal 'jupii', image_owner.name
    assert_not_nil image_owner.image
    assert_not_nil image_owner.image.id
  end

  test 'attachment gets updated with owner on update (and old attachment is destroyed)' do
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    image_owner = ImageOwner.create!(:image => { :uploaded_data => file_data }).reload
    assert_not_nil image_owner.image
    assert_equal 'attachment_file_test.jpg', File.basename(image_owner.image.full_filename)
    assert Image.exists?(image_id = image_owner.image.id)

    begin
      FileUtils.cp 'test/files/attachment_file_test.jpg', 'test/files/attachment_file_test2.jpg'
      file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test2.jpg'
      assert image_owner.update_attributes(:name => 'jupiii', :image => { :uploaded_data => file_data })
    ensure
      FileUtils.rm 'test/files/attachment_file_test2.jpg' rescue nil
    end

    assert_equal 'jupiii', image_owner.name
    assert_not_nil image_owner.image
    assert_not_nil image_owner.image.id
    assert_not_equal image_id, image_owner.image.id
    assert ! Image.exists?(image_id)
    assert_equal 'attachment_file_test2.jpg', File.basename(image_owner.image.full_filename)
  end

  class ValidatedImage < AttachmentFile

    has_attachment :storage => :db_file,
                   :content_type => :image,
                   :path_prefix => TEST_IMAGE_PATH_PREFIX,
                   :thumbnail_class => self, # store thumbnails with parent
                   :thumbnails => { :preview => '120x120>' },
                   :min_size => 1.kilobytes,
                   :max_size => 1.megabyte # test/files/attachment_file_test.png has 1.3 MB !

    validates_as_attachment :uploaded_data # validates image size constraint !

  end

  class ValidatedImageOwner < ActiveRecord::Base
    set_table_name 'validated_image_owners'

    validates_presence_of :name

    has_attachment_file :image, :class_name => 'ValidatedImage'

  end

  test 'attachment does not get saved with owner on create if is not valid (not an image)' do
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.pdf'

    image_owner = ValidatedImageOwner.new(:image => { :uploaded_data => file_data })
    assert ! image_owner.save

    assert ! image_owner.valid? # the image was invalid not the owner !
    assert ! image_owner.image.valid?
    
    assert_nil image_owner.image.id
  end

  test 'attachment does not get saved with owner on update if is not valid (too big)' do
    image_owner = ValidatedImageOwner.create! :name => 'huu'
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.png'
    assert ! image_owner.update_attributes(:name => 'mehehehe', :image => { :uploaded_data => file_data })

    assert ! image_owner.valid? # the image was invalid not the owner !
    assert_not_blank image_owner.errors.on(:'image.uploaded_data')

    assert_equal 'mehehehe', image_owner.name
    assert_not_nil image_owner.image
    assert_not_blank image_owner.image.errors
    assert_not_blank image_owner.image.errors.on(:uploaded_data)
    image_owner.reload
    assert_nil image_owner.image
  end

  test 'invalid (not an image) attachment does get saved with owner if validations are disabled' do
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.pdf'

    image_owner = ValidatedImageOwner.new(:name => nil, :image => { :uploaded_data => file_data })
    assert image_owner.save(false)

    assert image_owner.id
    assert image_owner.image.id
    assert_nil image_owner.image.find_thumbnail(:preview) # could not create thumbnail - not an image !
  end

  test 'invalid (too big) attachment does get saved with owner if validations are disabled 1' do
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.png'

    image_owner = ValidatedImageOwner.new(:name => nil, :image => { :uploaded_data => file_data })
    assert image_owner.save(false)
    assert image_owner.errors.blank? # name wasn't validated
    assert image_owner.image.errors.blank?

    assert image_owner.id
    assert image_owner.image.id
    # the attachment is saved but since validations are disabled thumb-nails are safe to not be generated !
    assert_nil image_owner.image.find_thumbnail(:preview)
  end

  test 'invalid (too big) attachment does get saved with owner if validations are disabled 2' do
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.png'

    image_owner = ValidatedImageOwner.new(:name => 'valid', :image => { :uploaded_data => file_data })
    assert image_owner.save(false)
    assert image_owner.errors.blank?
    assert image_owner.image.errors.blank?
    
    assert image_owner.id
    assert image_owner.image.id
    # the attachment is saved but since validations are disabled thumb-nails are safe to not be generated !
    assert_nil image_owner.image.find_thumbnail(:preview)
  end

  test 'previous attachment is kept if saving new attachment fails due to validation errors' do
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    image_owner = ValidatedImageOwner.create!(:name => 'huu', :image => { :uploaded_data => file_data })
    image_id = image_owner.image.id
    #assert ValidatedImage.exists?(image_id)

    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.png'
    assert ! image_owner.update_attributes(:name => 'mehehehe', :image => { :uploaded_data => file_data })

    assert ! image_owner.valid? # the image was invalid not the owner !
    
    assert_equal 'mehehehe', image_owner.name
    assert_not_nil image_owner.image
    assert_nil image_owner.image.id
    assert_not_blank image_owner.image.errors
    assert_not_blank image_owner.image.errors.on(:uploaded_data)
    image_owner.reload
    assert_not_nil image_owner.image
    assert_equal image_id, image_owner.image.id
    assert ValidatedImage.exists?(image_id)
  end

  test 'previous attachment is destroyed if saving a new valid attachment' do
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    image_owner = ValidatedImageOwner.create!(:name => 'huu', :image => { :uploaded_data => file_data })
    image_id = image_owner.image.id
    assert ValidatedImage.exists?(image_id)

    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    assert image_owner.update_attributes(:name => 'mehehehe', :image => { :uploaded_data => file_data })

    assert_equal 'mehehehe', image_owner.name
    assert_not_nil image_owner.image
    assert_not_nil image_owner.image.id
    assert_blank image_owner.image.errors
    image_owner.reload
    assert_not_nil image_owner.image
    assert_not_equal image_id, image_owner.image.id
    assert ! ValidatedImage.exists?(image_id)
  end

#  test 'attachment gets updated with owner on update but does not persist if invalid' do
#    #puts '1 ==============================='
#    #Image.all.each { |img| puts img.inspect }
#    #puts '================================='
#    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
#    image_owner = ValidatedImageOwner.create!(:image => { :uploaded_data => file_data }).reload
#    #puts '2 ==============================='
#    #Image.all.each { |img| puts img.inspect }
#    #puts '================================='
#    #image_owner = ImageOwner.find(image_owner.id)
#
#    assert_not_nil image_owner.image
#    assert ValidatedImage.exists?(image_id = image_owner.image.id)
#
#    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.pdf'
#    assert ! image_owner.update_attributes(:name => 'jupiii', :image => { :uploaded_data => file_data })
#    #puts '3 ==============================='
#    #Image.all.each { |img| puts img.inspect }
#    #puts '================================='
#
#    assert_equal 'jupiii', image_owner.name
#    assert_not_nil image_owner.image
#    assert_nil image_owner.image.id
#    # actually it does remove the previous attachment (re-submit of attachment expected) :
#    #puts '4 ==============================='
#    #Image.all.each { |img| puts img.inspect }
#    #puts '================================='
#    assert_nil ValidatedImageOwner.find(image_owner.id).image # TODO should this be changed !?
#  end

  test 'returns nil_path on missing attachment path' do
    image_owner = ImageOwner.create!

    nil_path = AttachmentFx::Owner.nil_path
    assert_equal nil_path, image_owner.image_path
    assert_equal nil_path, image_owner.image_full_path

    begin
      AttachmentFx::Owner.nil_path = '00'
      assert_equal '00', image_owner.image_path
      assert_equal '00', image_owner.image_full_path
    ensure
      AttachmentFx::Owner.nil_path = nil_path
    end

  end

  #

  test 'validates_as_attachment_and_reports_errors_on' do
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.pdf'
    image = ValidatedImage.new(:uploaded_data => file_data)

    assert ! image.save
    assert ! image.errors.blank?
    assert image.errors.on(:uploaded_data)
  end

  test 'validates_as_attachment_and_reports_errors_on_throught_owner' do # owner valid
    file_data = AttachmentFile.file_as_uploaded_data 'test/files/attachment_file_test.pdf'
    image_owner = ValidatedImageOwner.new(:image => { :uploaded_data => file_data })

    assert ! image_owner.save
    assert ! image_owner.errors.blank?
    assert ! image_owner.image.errors.blank?
    assert image_owner.image.errors.on(:uploaded_data)
  end

#  class ::TouchedImage < AttachmentFile
#
#    has_attachment :storage => :db_file,
#                   :content_type => :image,
#                   :path_prefix => TEST_IMAGE_PATH_PREFIX,
#
#                   :owner => { :touch => true }
#
#  end
#
#  class ::TouchedImageOwner < ActiveRecord::Base
#
#    has_attachment_file :image, :class_name => 'TouchedImage'
#
#  end
#
#  test "touched image might be persisted" do
#    file = File.join(TEST_FILES_PATH, 'attachment_file_test.jpg')
#    image = TouchedImage.new_from_file(file)
#    assert image.save, "save failed: #{image.errors.inspect}"
#  end
#
#  test "touched image on save touches owner" do
#    owner = TouchedImageOwner.create!
#    updated_at = owner.reload.update_at
#    sleep(1)
#  end

  private

    def clear_images_dir
      images_dir = File.join File.dirname(__FILE__), TEST_IMAGE_PATH_PREFIX
      FileUtils.rm_f(images_dir) if File.exist?(images_dir)
      FileUtils.mkdir_p images_dir
    end

end
