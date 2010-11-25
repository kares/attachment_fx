require File.expand_path('test_helper', File.dirname(__FILE__))

class DbFileHelpersTest < ActiveSupport::TestCase

  TEST_FILES_PATH = File.join(File.dirname(__FILE__), 'files')

  TEST_IMAGE_PATH_PREFIX = 'public/files/db_images'

  FileUtils.rm_f(TEST_IMAGE_PATH_PREFIX) if File.exist?(TEST_IMAGE_PATH_PREFIX)
  FileUtils.mkdir_p TEST_IMAGE_PATH_PREFIX

  load_schema! 'schema.rb'

  class AttachmentFile < ActiveRecord::Base
    set_table_name 'attachment_files'
    
    has_attachment :storage => :db_file,
                   :processor => :mini_magick
  end

  class Image1 < AttachmentFile
    
    has_attachment :storage => :db_file,
                   :content_type => :image,
                   :path_prefix => File.join(TEST_IMAGE_PATH_PREFIX, 'images1'),
                   :thumbnail_class => self, # store thumb-nails with parent
                   :thumbnails => { :big => '96x96>', :small => '48x48>' }

  end

  class Image2 < AttachmentFile

    class Thumb < AttachmentFile

      attachment_options[:path_prefix] = File.join(TEST_IMAGE_PATH_PREFIX, 'images2/thumbs')

    end

    has_attachment :storage => :db_file,
                   :content_type => :image,
                   :path_prefix => File.join(TEST_IMAGE_PATH_PREFIX, 'images2'),
                   :resize_to => '192x192>', # not wider than 192 pixels
                   :thumbnail_class => Thumb,
                   :thumbnails => { :half => '96x96>' }

  end

  test 'db files have a file interface' do
    assert Image1.new.respond_to? :full_filename
    assert Image1.new.respond_to? :public_filename
  end

  test 'db files are different files when created from same file' do
    file_data = Image1.file_as_uploaded_data 'test/files/attachment_file_test.png'
    attach1 = Image1.create(:uploaded_data => file_data)

    file_data = Image1.file_as_uploaded_data 'test/files/attachment_file_test.png'
    attach2 = Image1.create(:uploaded_data => file_data)

    assert_not_equal(attach1.full_filename, attach2.full_filename)
    dir1 = File.dirname attach1.full_filename
    dir2 = File.dirname attach2.full_filename
    assert_not_equal(dir1, dir2)
  end

  test 'db files are downloaded under specified path_prefix' do
    file_data = Image1.file_as_uploaded_data 'test/files/attachment_file_test.png'
    attach1 = Image1.create(:uploaded_data => file_data)

    file_data = Image2.file_as_uploaded_data 'test/files/attachment_file_test.png'
    attach2 = Image2.create(:uploaded_data => file_data)

    images1_path_prefix = File.expand_path(File.join(TEST_IMAGE_PATH_PREFIX, 'images1'), RAILS_ROOT)
    images2_path_prefix = File.expand_path(File.join(TEST_IMAGE_PATH_PREFIX, 'images2'), RAILS_ROOT)

    dir1 = File.dirname(attach1.full_filename)
    dir2 = File.dirname(attach2.full_filename)
    assert dir1.index images1_path_prefix
    assert dir2.index images2_path_prefix
  end

  test 'db files are stored in different subdirs' do
    file_data = Image1.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    attach1 = Image1.create(:uploaded_data => file_data)

    file_data = Image1.file_as_uploaded_data 'test/files/attachment_file_test.png'
    attach2 = Image1.create(:uploaded_data => file_data)

    assert_not_equal(attach1.full_filename, attach2.full_filename)
    dir1 = File.dirname attach1.full_filename
    dir2 = File.dirname attach2.full_filename
    assert_not_equal(dir1, dir2)
  end

  test 'db file thumbnails are in the same dir if same class as thumbnail class' do
    file_data = Image1.file_as_uploaded_data 'test/files/attachment_file_test.jpg'
    attach1 = Image1.create(:uploaded_data => file_data)

    assert_not_equal(attach1.full_filename, attach1.full_filename(:big))
    assert_not_equal(attach1.full_filename(:big), attach1.full_filename(:small))
    dir = File.dirname attach1.full_filename
    dir_big = File.dirname attach1.full_filename(:big)
    dir_small = File.dirname attach1.full_filename(:small)
    assert_equal(dir, dir_big)
    assert_equal(dir_small, dir_big)
  end

  test 'db file thumbnails are stored in different dirs' do
    file_data = Image2.file_as_uploaded_data 'test/files/attachment_file_test.png'
    attach2 = Image2.create(:uploaded_data => file_data)

    dir = File.dirname attach2.full_filename
    dir_half = File.dirname attach2.full_filename(:half)
    assert_not_equal(dir, dir_half)
  end

end
