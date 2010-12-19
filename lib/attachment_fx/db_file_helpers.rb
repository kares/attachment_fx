require 'fileutils'
require 'digest/sha2'

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
        unless self_file = thumbnail ? find_thumbnail(thumbnail) : self
          raise "couldn't find thumbnail #{thumbnail.inspect} for #{self.inspect}"
        end
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
        #file_system_path = (thumbnail ? thumbnail_class : self.class).path_prefix
        file_system_path = (thumbnail ? thumbnail_class : self.class).attachment_options[:path_prefix].to_s
        File.join(RAILS_ROOT, file_system_path, *partitioned_path( thumbnail_name_for(thumbnail) ))
      end

      # Partitions the given path into an array of path components.
      #
      # For example, given an <tt>*args</tt> of ["foo", "bar"], it will return
      # <tt>["0000", "0001", "foo", "bar"]</tt> (assuming that that id returns 1).
      #
      # If the id is not an integer, then path partitioning will be performed by
      # hashing the string value of the id with SHA-512, and splitting the result
      # into 4 components. If the id a 128-bit UUID (as set by :uuid_primary_key => true)
      # then it will be split into 2 components.
      #
      # To turn this off entirely, set :partition => false.
      def partitioned_path(*args)
        if respond_to?(:attachment_options) && attachment_options[:partition] == false
          args
        elsif attachment_options[:uuid_primary_key]
          # Primary key is a 128-bit UUID in hex format. Split it into 2 components.
          path_id = attachment_path_id.to_s
          component1 = path_id[0..15] || "-"
          component2 = path_id[16..-1] || "-"
          [component1, component2] + args
        else
          path_id = attachment_path_id
          if path_id.is_a?(Integer)
            # Primary key is an integer. Split it after padding it with 0.
            (( path_id.to_s.length > 8 ? "%012d" : "%08d" ) % path_id).scan(/..../) + args
          else
            # Primary key is a String. Hash it, then split it into 4 components.
            hash = Digest::SHA512.hexdigest(path_id.to_s)
            [hash[0..31], hash[32..63], hash[64..95], hash[96..127]] + args
          end
        end
      end

      # The attachment ID used in the full path of a file
      def attachment_path_id
        ((respond_to?(:parent_id) && parent_id) || id) || 0
      end

  end

end
