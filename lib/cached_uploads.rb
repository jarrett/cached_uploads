require 'fileutils'
require 'digest/md5'
require 'active_support/concern'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/hash/reverse_merge'

# This module enables you to upload files and persist them in a cache in the event that
# the form must be redisplayed (e.g. due to validation errors). This module also saves
# the files to their final location when the record is saved.
# 
# The controller is still responsible for the overall workflow. It should use the normal
# ActiveRecord API, with one addition: If the submission is invalid, the controller must
# call #write_temporary_files.
#
# The controller (or cron task, or a worker process) should also call
# .clean_temporary_files from time to time. An easy option is to clean up any time an
# invalid submission is received.
module CachedUploads
  extend ActiveSupport::Concern
  
  def delete_permanent_file(file_attr)
    config = self.class.cached_uploads[file_attr.to_sym]
    prm_path = send config[:prm_path_method]
    if File.exists?(prm_path)
      File.delete prm_path
    end
  end
  
  def write_permanent_file_md5(file_attr)
    config = self.class.cached_uploads[file_attr.to_sym]    
    file = send file_attr
    method = "#{config[:prm_md5_attr]}="
    if file.present? and respond_to?(method)
      file.rewind
      md5 = Digest::MD5.hexdigest(file.read)
      send method, md5
    end
  end
  
  def write_permanent_file(file_attr)
    config = self.class.cached_uploads[file_attr.to_sym]    
    uploaded_file = send file_attr
    
    if uploaded_file.present?
      # This *won't* execute if we've set the temporary file MD5 attribute instead of the
      # file attribute. It will only execute if we're uploading the file for the first time.
      # (Technically, if both the file and the MD5 are present, this would execute. But that
      # would be an error state.)
      
      prm_file_path = send config[:prm_path_method]
      File.open(prm_file_path, 'wb') do |out_file|
        uploaded_file.rewind
        out_file.write uploaded_file.read
      end
    elsif send(config[:tmp_md5_attr]).present?
      # This executes if we've set the temporary file MD5 attribute instead of the file
      # attribute. This is invoked when the user has submitted invalid data at least once.
      # In which case we've saved the uploaded data to a tempfile on the server. Now the
      # user is resubmitting with correct data. (We know it's correct because
      # #write_permanent_file is triggered by an after_save callback.)
      
      tmp_file_path = send config[:tmp_path_method]
      prm_file_path = send config[:prm_path_method]
      FileUtils.cp tmp_file_path, prm_file_path
    end
  end
  
  # Writes the temporary file, basing its name on the MD5 hash of the uploaded file.
  # Raises if the uploaded file is #blank?.
  def write_temporary_file(file_attr)
    config = self.class.cached_uploads[file_attr.to_sym]
    file = send file_attr
    
    if file.present?
      # Read the uploaded file, calc its MD5, and write the MD5 instance variable.
      file.rewind
      md5 = Digest::MD5.hexdigest(file.read)
      send "#{config[:tmp_md5_attr]}=", md5
      
      # Write the temporary file, using its MD5 hash to generate the filename.
      file.rewind
      File.open(send(config[:tmp_path_method]), 'wb') do |out_file|
        out_file.write file.read
      end
    else
      raise "Called #write_temporary_file(:#{file_attr}), but ##{file_attr} was not present."
    end
  end
  
  # Saves any configured temporary files. Controllers should call this method when an
  # invalid submission is received. Does not save a temporary file if the file itself
  # had a validation error.
  def write_temporary_files
    cached_uploads.each_key do |file_attr|
      if errors[:file].empty? and send(file_attr).present?
        write_temporary_file file_attr
      end
    end
  end
  
  included do
    class_attribute :cached_uploads
  end
  
  module ClassMethods
    # Cleans out all temporary files older than the given age.
    # Typically called by the controller.
    def clean_temporary_files
      cached_uploads.each do |file_attr, config|
        folder = send config[:tmp_folder_method]
        pattern = File.join folder, '*'
      
        Dir.glob(pattern).each do |path|
          if File.basename(path) != '.gitignore' and File.mtime(path) < config[:tmp_file_expiration].ago
            File.delete path
          end
        end
      end
    end
    
    # Reader and writer methods will be defined for the +file_attr+ name.
    # 
    # CachedUploads looks for class and instance methods defining the permanent file path,
    # the temporary file path, and the temporary file folder path. If the file attribute
    # is for example #screenshot, then the path methods will be, respectively,
    # #screenshot_path, #tmp_screenshot_path, and .tmp_screenshot folder. The names of
    # those methods may be overridden--see the "Options" documentation below.
    # 
    # You may define the path methods like any normal instance method. For convenience
    # and to keep all related code in one place, you may also pass Procs when you call
    # .has_cached_uploads, and the methods will be defined for you using the Procs. For
    # example, instead of explicitly defining a #screenshot_path method, you can do this:
    # 
    #   has_cached_upload(:screenshot, {
    #     folder:   ->()    { File.join Rails.root, 'uploads/screenshots' },
    #     filename: ->(obj) { "#{obj.id}.png"                             }
    #   })
    # 
    # CachedUploads will then automatically define #screenshot_path using the given
    # +folder+ and +filename+ Procs.
    # 
    # You may also define an instance attribute storing the uploaded file's extension.
    # If +file_attr+ is #screenshot, then by default the extension attribute is
    # #screenshot_ext. If the class responds to the extension attribute, then that
    # attribute will be set automatically when the file attribute's writer is called.
    # For example, if the file attribute is #screenshot, then calling #screenshot= will
    # cause #screenshot_ext to be set.
    # 
    # Options:
    #
    # - +folder+: A Proc that returns an absolute path to the permanent files' folder.
    # 
    # - +filename+: A Proc that accepts an instance of the class and returns the permanent
    #   filename. Do not include the folder path in the returned value.
    # 
    # - +tmp_folder+: Like +folder+, but for the temporary files.
    # 
    # - +tmp_filename+: Like +filename+, but for the temporary files.
    # 
    # - +prm_path_method+: Name of the instance method that returns the path to the
    #   permanent file. Defaults to +"#{file_attr}_path"+.
    # 
    # - +tmp_path_method+: Name of the instance method that returns the path to the
    #   temporary file. Defaults to +"tmp_#{file_attr}_path"+.
    # 
    # - +tmp_folder_method+: Name of the instance method that returns the path to the
    #   temporary files' folder. Defaults to +"tmp_#{file_attr}_folder"+.
    # 
    # - +tmp_file_expiration+: Optional. Length of time temporary files last before being
    #   cleaned out. Defaults to +48.hours+.
    # 
    # - +ext_attr+: Name of the instance attribute storing the file's extension. Defaults
    #   to +"#{file_attr}_ext"+. CachedUploads does not define this method for you.
    #   Typically, this attribute would be a database column.
    # 
    # - +prm_md5_attr+: Name of the instance attribute storing the permanent file's MD5
    #   hash. Defaults to +"#{file_attr}_md5"+. If this attribute exists, it should be a
    #   database column, but it need not exist at all.
    #
    # - +tmp_md5_attr+: Name of the instance attribute storing the temporary file's MD5
    #   hash. Defaults to +"tmp_#{file_attr}_md5"+. This attribute is typically not a
    #   database column. If you don't define it yourself, CachedUploads will define it
    #   for you.
    # 
    # - +no_prm:+ If set to true, permanent files won't be written to disk. You might
    #   want to use this if, for example, you're hosting uploaded files on an external
    #   CDN. Options related to the permanent file have no effect when this option is
    #   true.
    def has_cached_upload(file_attr, options = {})
      # Set default configs.
      options.reverse_merge!(
        prm_path_method:     "#{file_attr}_path",
        tmp_path_method:     "tmp_#{file_attr}_path",
        tmp_folder_method:   "tmp_#{file_attr}_folder",
        tmp_file_expiration: 48.hours,
        ext_attr:            "#{file_attr}_ext",
        prm_md5_attr:        "#{file_attr}_md5",
        tmp_md5_attr:        "tmp_#{file_attr}_md5"
      )
      
      # Initialize the configs hash.
      self.cached_uploads ||= {}
      cached_uploads[file_attr.to_sym] = options
      
      # Define the reader for the file.
      attr_reader file_attr
      
      # Define the writer for the file.
      class_eval %Q(
        def #{file_attr}=(f)
          @#{file_attr} = f
          if respond_to?('#{options[:ext_attr]}=')
            self.#{options[:ext_attr]} = File.extname(f.original_filename)
          end
        end
      )
      
      # Define the accessor for the temporary file MD5 string. This should never be a
      # database column.
      unless method_defined? options[:tmp_md5_attr]
        attr_accessor options[:tmp_md5_attr]
      end
      
      # Define the path methods, if given.
      if options[:folder] and options[:filename]
        define_singleton_method "#{file_attr}_folder" do
          options[:folder].call self
        end
        
        define_method "#{file_attr}_filename" do
          options[:filename].call(self)
        end
        
        define_method "#{file_attr}_path" do
          File.join self.class.send("#{file_attr}_folder"), send("#{file_attr}_filename")
        end
      end
      
      # Define the temporary path methods, if given.
      if options[:tmp_folder] and options[:tmp_filename]
        define_singleton_method "tmp_#{file_attr}_folder" do
          options[:tmp_folder].call self
        end
        
        define_method "tmp_#{file_attr}_filename" do
          options[:tmp_filename].call(self)
        end
        
        define_method "tmp_#{file_attr}_path" do
          File.join self.class.send("tmp_#{file_attr}_folder"), send("tmp_#{file_attr}_filename")
        end
      end
      
      unless options[:no_prm]
        # Register the save callback.      
        after_save do |obj|
          obj.write_permanent_file file_attr
        end
      
        # Register the delete callback.
        after_destroy do |obj|
          obj.delete_permanent_file file_attr
        end
      end
      
      # Register the hash writer callback.
      before_save do |obj|
        obj.write_permanent_file_md5 file_attr
      end
    end
  end
end