require 'test_helper'
require 'ostruct'

class ActiveRecordTest < MiniTest::Unit::TestCase
  def setup
    Upload.create_folders
  end
  
  def test_does_not_overwrite_ar_columns
    src_file = Rack::Test::UploadedFile.new TEST_FILE_PATH, 'text/plain'
    upload = ActiveRecordUpload.new
    upload.file = src_file
    upload.write_temporary_file :file
    upload.save
    assert(
      upload.instance_variable_get('@file_md5').nil?,
      "@file_md5 was set, which probably means has_cached_upload mistakenly called attr_accesor(:file_md5)"
    )
    assert_equal TEST_FILE_MD5, upload.attributes[:file_md5]
  end
  
  # In ActiveRecord::Base, for some reason respond_to? sometimes returns false for
  # database column names. That caused a bug in a real application, wherein CachedUploads
  # mistakenly called attr_accessor(:file_md5) even though that column existed. To
  # simulate that kind of situation, we mock ActiveRecord's attributes using method_missing.
  class ActiveRecordUpload
    include CachedUploads
    include CachedUploads::MockActiveRecord
    
    # Must come before has_cached_upload
    def self.columns
      [OpenStruct.new(name: :file_md5)]
    end
    
    has_cached_upload(
      :file,
      folder:       ->(u) { File.join UPLOADS_DIR, 'prm_files' },
      tmp_folder:   ->(u) { File.join UPLOADS_DIR, 'tmp_files' },
      filename:     ->(u) { "#{u.name}#{u.file_ext}"           },
      tmp_filename: ->(u) { "#{u.file_md5}#{u.file_ext}"       }
    )
    
    def attributes
      @attributes
    end
    
    attr_accessor :file_ext
    
    def initialize
      @attributes = {}
    end
    
    def method_missing(sym, *args)
      if sym == 'file_md5='.to_sym
        @attributes[:file_md5] = args.first
      elsif sym == :file_md5
        @attributes[:file_md5]
      else
        super
      end
    end
    
    attr_accessor :name
  end
end