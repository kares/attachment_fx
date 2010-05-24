
module AttachmentFx

  # Helper module for db_file as it basically does nothing more than storing
  # in DB. It's extended to behave like if the attachments where stored in FS.
  # @see attachment_fu/backends/db_file_backennd.rb !
  module DbFileHelpers

#    def save_to_storage
#      puts "save_to_storage: save_attachment? = #{save_attachment?.inspect}"
#      returning super do
#        puts "save_to_storage: db_file = #{db_file.inspect}"
#      end
#    end

    # Gets the full path to the filename in this format:
    #
    #   # This assumes a model name like MyModel
    #   # public/#{table_name} is the default filesystem path
    #   RAILS_ROOT/public/my_models/5/blah.jpg
    #
    def full_filename(thumbnail = nil)
      returning absolute_filepath(thumbnail) do |filepath|
        unless File.exists?(filepath)
          self_file = thumbnail ? find_thumbnail(thumbnail) : self
          temp_file = self_file.create_temp_file
          FileUtils.mkpath File.dirname(filepath)
          FileUtils.copy temp_file.path, filepath
          # it's in public thus needs to be world readable :
          FileUtils.chmod 0644, filepath # u+rw g+r o+r
        end
      end
    end

    #@@public_path_sub = nil
    # Gets the public path to the file
    # The optional thumbnail argument will output the thumbnail's filename.
    def public_filename(thumbnail = nil)
      #@@public_path_sub ||= %r(^#{Regexp.escape(AttachmentFx::PUBLIC_PATH)})
      full_filename(thumbnail).sub(AttachmentFx::PUBLIC_PATH, '')
    end

    def destroy_file
      result = super # and remove the 'cached' public file path if any :
      filepath = absolute_filepath
      #@absolute_filepath = nil
      dirname = File.dirname(filepath)
      FileUtils.rm_r(dirname, :force => true) if File.exists?(dirname)
      return result
    rescue
      logger.info "destroy_file() filepath = #{filepath.inspect}: [#{$!.class.name}] #{$1.to_s}"
      logger.warn $!.backtrace.collect { |b| " > #{b}" }.join("\n")
    end

    private

      def absolute_filepath(thumbnail = nil)
        #@absolute_filepath ||= {}
        #if fpath = @absolute_filepath[thumbnail.to_s]
        #  return fpath
        #end
        raise ActiveRecord::ActiveRecordError.new("not yet saved") if new_record?
        file_system_path = (thumbnail ? thumbnail_class : self.class).path_prefix
        filename = thumbnail_name_for(thumbnail)
        #@absolute_filepath[thumbnail.to_s] =
          File.join(RAILS_ROOT, file_system_path, *partitioned_path(filename))
      end

      def partitioned_path(*args) # the id is used in the full path of a file :
        attachment_path_id = ((respond_to?(:parent_id) && parent_id) || id).to_i
        ("%08d" % attachment_path_id).scan(/..../) + args
      end

  end

end
