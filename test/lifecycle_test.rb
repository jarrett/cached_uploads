require 'test_helper'

class LifecycleTest < MiniTest::Unit::TestCase
  def setup
    Upload.create_folders
  end
  
  def test_write_temporary_file
    src_file = Rack::Test::UploadedFile.new TEST_FILE_PATH, 'text/plain'
    upload = Upload.new
    upload.file = src_file
    upload.write_temporary_file :file
    tmp_file_path = File.join(UPLOADS_DIR, 'tmp_files', TEST_FILE_MD5 + '.txt')
    
    File.open(tmp_file_path, 'rb') do |f|
      assert_equal TEST_FILE_MD5, Digest::MD5.hexdigest(f.read)
    end
    assert_equal TEST_FILE_MD5, upload.file_md5
  end
  
  def test_write_permanent_file_with_file_set
    src_file = Rack::Test::UploadedFile.new TEST_FILE_PATH, 'image/jpeg'
    upload = Upload.new
    upload.file = src_file
    upload.name = 'banana'
    upload.save
    
    file_path = File.join UPLOADS_DIR, 'prm_files/banana.txt'
    assert File.exists?(file_path), "Expected #{file_path.inspect} to exist"
    File.open(file_path, 'rb') do |f|
      assert_equal TEST_FILE_MD5, Digest::MD5.hexdigest(f.read)
    end
  end
  
  def test_write_permanent_file_with_file_md5_set
    # Instantiate an Upload and write its temp file to disk.
    src_file = Rack::Test::UploadedFile.new TEST_FILE_PATH, 'image/jpeg'
    upload1 = Upload.new
    upload1.file = src_file
    upload1.write_temporary_file :file
    
    # Instantiate a new Upload, this time passing in the first one's MD5 hash.
    # We'll see if this second Upload correctly copies the data from the temporary
    # file to the permanent one.
    upload2 = Upload.new
    upload2.file_md5 = upload1.file_md5
    upload2.file_ext = '.txt'
    upload2.name = 'mango'
    upload2.save
    
    # Verify that the data has been copied from the temp file to the permanent one.
    file_path = File.join UPLOADS_DIR, 'prm_files/mango.txt'
    assert File.exists?(file_path), "Expected #{file_path.inspect} to exist"
    File.open(file_path, 'rb') do |f|
      assert_equal TEST_FILE_MD5, Digest::MD5.hexdigest(f.read)
    end
  end
  
  def test_writes_hash
    src_file = Rack::Test::UploadedFile.new TEST_FILE_PATH, 'image/jpeg'
    upload = Upload.new
    upload.file = src_file
    upload.name = 'banana'
    upload.save
    assert_equal TEST_FILE_MD5, upload.file_md5
  end
end