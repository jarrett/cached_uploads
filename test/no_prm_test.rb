require 'test_helper'

class NoPrmTest < MiniTest::Unit::TestCase
  def setup
    Upload.create_folders
  end
  
  def test_does_not_save_permanent_file
    src_file = Rack::Test::UploadedFile.new TEST_FILE_PATH, 'image/jpeg'
    upload = NoPrmUpload.new
    upload.file = src_file
    upload.name = 'banana'
    upload.save
    
    file_path = File.join UPLOADS_DIR, 'prm_files/banana.txt'
    assert !File.exists?(file_path), "Expected #{file_path.inspect} not to exist"
  end
  
  def test_does_save_temporary_file
    src_file = Rack::Test::UploadedFile.new TEST_FILE_PATH, 'text/plain'
    upload = NoPrmUpload.new
    upload.file = src_file
    upload.write_temporary_file :file
    tmp_file_path = File.join(UPLOADS_DIR, 'tmp_files', TEST_FILE_MD5 + '.txt')
    
    File.open(tmp_file_path, 'rb') do |f|
      assert_equal TEST_FILE_MD5, Digest::MD5.hexdigest(f.read)
    end
    assert_equal TEST_FILE_MD5, upload.tmp_file_md5
  end
  
  class NoPrmUpload
    include CachedUploads
    include CachedUploads::MockActiveRecord
  
    has_cached_upload(
      :file,
      no_prm: true,
      tmp_folder:   ->(u) { File.join UPLOADS_DIR, 'tmp_files' },
      tmp_filename: ->(u) { "#{u.tmp_file_md5}#{u.file_ext}"   }
    )
  
    def self.create_folders
      FileUtils.mkdir_p File.join(UPLOADS_DIR, 'tmp_files')
    end
  
    attr_accessor :file_ext
  
    attr_accessor :name
  end
end