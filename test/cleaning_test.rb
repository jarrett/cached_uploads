require 'test_helper'

class CleaningTest < MiniTest::Unit::TestCase
  def setup
    Upload.create_folders
  end
  
  def test_does_not_delete_gitignore
    path = File.join(UPLOADS_DIR, 'tmp_files/.gitignore')
    FileUtils.touch path
    Upload.clean_temporary_files
    assert File.exists?(path)
  end
  
  def test_does_not_delete_files_less_than_48_hours_old
    path = File.join UPLOADS_DIR, 'tmp_files/foo.txt'
    File.open(path, 'w') { |f| f << 'Testing' }
    Timecop.travel(47.hours.from_now) do
      Upload.clean_temporary_files
    end
    assert File.exists?(path)
  end
  
  def test_deletes_files_more_than_48_hours_old
    path = File.join UPLOADS_DIR, 'tmp_files/foo.txt'
    File.open(path, 'w') { |f| f << 'Testing' }
    Timecop.travel(49.hours.from_now) do
      Upload.clean_temporary_files
    end
    assert !File.exists?(path)
  end
end