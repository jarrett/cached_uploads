# Gem Deprecated!

This gem is deprecated. Please use [Echo Uploads](https://github.com/jarrett/echo_uploads) instead.

## Cached Uploads for Rails

This module enables you to upload files and persist them in a cache in the event that
the form must be redisplayed (e.g. due to validation errors). This module also saves
the files to their final location when the record is saved.
 
The controller is still responsible for the overall workflow. It should use the normal
ActiveRecord API, with one addition: If the submission is invalid, the controller must
call #write_temporary_files.

The controller (or cron task, or a worker process) should also call
.clean_temporary_files from time to time. An easy option is to clean up any time an
invalid submission is received.

## Usage

In the model:

    class UserAvatar      
      has_cached_upload(:file, {
        folder:       ->()  { File.join Rails.root, 'uploads/screenshots'     },
        tmp_folder:   ->()  { File.join Rails.root, 'uploads/tmp_screenshots' },
        filename:     ->(a) { "#{a.id}.png"                                   },
        tmp_filename: ->(a) { "#{a.tmp_file_md5}#{a.file_ext}"                    }
      })
      
      # This could be a database column instead.
      attr_accessor :file_ext
    end

See the comments in `cached_uploads.rb` for more details.

In the form:

    <% if f.object.tmp_file_md5.present? %>
      <!-- These fields make the form "remember" the uploaded file 
      when validation fails. -->
      <%= f.hidden_field :tmp_file_md5 %>
      <%= f.hidden_field :file_ext %>
    <% else %>
      <%= f.label :file, 'File:' %>
      <%= f.file_field :file %>
    <% end %>

## Testing

In the example above, your test cases would be writing to the same folder as your
development server. That's probably not desirable. An improved solution would be something
like this:
    
    # In environments/development.rb and environments/production.rb
    config.uploads_dir = File.join Rails.root, 'uploads'
    
    # In environments/test.rb
    config.uploads_dir = File.join Rails.root, 'test_uploads'
    
    # In user_avatar.rb
    has_cached_upload(:file, {
      folder:       ->()  { File.join Rails.configuration.uploads_dir, 'screenshots'     },
      tmp_folder:   ->()  { File.join Rails.configuration.uploads_dir, 'tmp_screenshots' },
      filename:     ->(a) { "#{a.id}.png"                                                },
      tmp_filename: ->(a) { "#{a.tmp_file_md5}#{a.file_ext}"                             }
    })
