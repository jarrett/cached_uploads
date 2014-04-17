require 'minitest/unit'
require 'turn/autorun'
require 'rack/test'
require 'timecop'

$:.unshift(File.join(File.expand_path(File.dirname(__FILE__)), '../lib'))

require 'cached_uploads'

UPLOADS_DIR = File.join(File.expand_path(File.dirname(__FILE__)), 'uploads')
TEST_FILE_PATH = File.join(File.expand_path(File.dirname(__FILE__)), 'file.txt')
TEST_FILE_MD5 = '3de8f8b0dc94b8c2230fab9ec0ba0506'

class MiniTest::Unit::TestCase
  def teardown
    FileUtils.rm_rf Dir.glob(File.join(UPLOADS_DIR, '**/*'))
  end
end

# To test the module, we need to include it in a class and call the module's config
# methods. Below, we set up a basic use case. Some tests may need to configure the module
# differently, in which case they won't be able to use this class and will need to define
# their own mock classes. Those mock classes should take advantage of the
# MockActiveRecord module.
module CachedUploads
  module MockActiveRecord
    extend ActiveSupport::Concern
    
    included do
      class_attribute :after_save_callbacks
      class_attribute :after_destroy_callbacks
      class_attribute :before_save_callbacks
      self.after_save_callbacks = []
      self.after_destroy_callbacks = []
      self.before_save_callbacks = []
    end
    
    module ClassMethods
      def after_save(&proc)
        after_save_callbacks << proc
      end
      
      def after_destroy(&proc)
        after_destroy_callbacks << proc
      end
      
      def before_save(&proc)
        before_save_callbacks << proc
      end
    end
    
    def destroy
      self.class.after_destroy_callbacks.each { |proc| proc.call self }
    end
    
    def save
      self.class.before_save_callbacks.each { |proc| proc.call self }
      self.class.after_save_callbacks.each { |proc| proc.call self }
    end
  end
end

class Upload
  include CachedUploads
  include CachedUploads::MockActiveRecord
  
  has_cached_upload(
    :file,
    folder:       ->(u) { File.join UPLOADS_DIR, 'prm_files' },
    tmp_folder:   ->(u) { File.join UPLOADS_DIR, 'tmp_files' },
    filename:     ->(u) { "#{u.name}#{u.file_ext}"           },
    tmp_filename: ->(u) { "#{u.tmp_file_md5}#{u.file_ext}"   }
  )
  
  def self.create_folders
    ['prm_files', 'tmp_files'].each do |dir|
      FileUtils.mkdir_p File.join(UPLOADS_DIR, dir)
    end
  end
  
  attr_accessor :file_ext
  
  attr_accessor :file_md5
  
  attr_accessor :name
end