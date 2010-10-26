
module AttachmentFx

  # Helper for the :db_file storage backend as attachment_fu only provides a 
  # data retrieval api (@see the current_data method).
  # The DbFileBackend with this module is extended to behave like if the
  # attachments where stored in the file system, as the file data is downloaded
  # on demand. The :path_prefix attachment option is used to determine the base
  # directory where the db files will get stored.
  #
  # @see Technoweenie::AttachmentFu::Backends::DbFileBackend
  module DbFileHelpers

    # Gets the full path to the filename.
    # 
    # Inspired by the file system backend full_filename implementation.
    # @see Technoweenie::AttachmentFu::Backends::FileSystemBackend#full_filename
    def full_filename(thumbnail = nil)
      @absolute_filepath ||= {}
      if filepath = @absolute_filepath[thumbnail.to_s]
        return filepath
      end
      filepath = absolute_filepath(thumbnail)
      unless File.exists?(filepath)
        self_file = thumbnail ? find_thumbnail(thumbnail) : self
        temp_file = self_file.create_temp_file
        FileUtils.mkpath File.dirname(filepath)
        FileUtils.copy temp_file.path, filepath
        # it's in public thus needs to be world readable :
        FileUtils.chmod 0644, filepath # u+rw g+r o+r
      end
      @absolute_filepath[thumbnail.to_s] = filepath
    end

    # Gets the public path to the file.
    # The optional thumbnail argument will output the thumbnail's filename.
    #
    # @see Technoweenie::AttachmentFu::Backends::FileSystemBackend#public_filename
    def public_filename(thumbnail = nil)
      #public_path_sub ||= %r(^#{Regexp.escape(AttachmentFx::PUBLIC_PATH)})
      full_filename(thumbnail).sub(AttachmentFx::PUBLIC_PATH, '')
    end

    def destroy_file
      result = super # and remove the 'cached' public file path if any :
      @absolute_filepath = nil
      filepath = absolute_filepath
      dirname = File.dirname(filepath)
      FileUtils.rm_r(dirname, :force => true) if File.exists?(dirname)
      return result
    rescue
      logger.info "destroy_file() filepath = #{filepath.inspect}: [#{$!.class.name}] #{$1.to_s}"
      logger.warn $!.backtrace.collect { |b| " > #{b}" }.join("\n")
    end

    private

      def absolute_filepath(thumbnail = nil)
        raise ActiveRecord::ActiveRecordError.new("not yet saved") if new_record?
        file_system_path = (thumbnail ? thumbnail_class : self.class).path_prefix
        filename = thumbnail_name_for(thumbnail)
        File.join(RAILS_ROOT, file_system_path, *partitioned_path(filename))
      end

      def partitioned_path(*args) # the id is used in the full path of a file :
        attachment_path_id = ((respond_to?(:parent_id) && parent_id) || id).to_i
        ("%08d" % attachment_path_id).scan(/..../) + args
      end

  end

end
