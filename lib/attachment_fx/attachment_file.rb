#
# Sample table rows for attachment_files :
#
#  id           :integer(4)
#  type         :string(255)
#  parent_id    :integer(4)
#  content_type :string(50)
#  filename     :string(50)
#  thumbnail    :string(20)
#  size         :integer(4)
#  width        :integer(4)
#  height       :integer(4)
#  owner_id     :integer(4)
#  owner_type   :string(20)
#  db_file_id   :integer(4)
#

begin
  require 'mime/types' # gem 'mime-types'
rescue LoadError
end

module AttachmentFx
  
  # Helper model class, this represents an attachment meta-data stored in the DB
  # (e.g. icons). The class attributes follows the 'attachment_fu' conventions.
  module AttachmentFile

    def self.included(base)
      options = base.attachment_options[:owner] || {}
      # :storage => :db_file,
      # :path_prefix => "public/attachment_files",
      # :thumbnail_class => AttachmentFile
      # :owner => { :touch => false, :polymorphic => true }
      #options[:touch] = false unless options.has_key?(:touch)
      # NOTE: owner touch makes no sense + messes up save recursively !
      if touch = options.delete(:touch)
        RAILS_DEFAULT_LOGGER.info "#{base} :owner => { :touch => #{touch} } attachment option ignored !"
      end
      options[:polymorphic] = true unless options.has_key?(:polymorphic)

      base.belongs_to :owner, options

      ##
      update_cache_callback = Proc.new do |attachment|

        owner = if attachment.respond_to?(:proxy_owner)
          attachment.proxy_owner
        else
          attachment.owner(false)
        #else
        #  nil
        end

        # unwrap ActiveRecord::Associations::BelongsToPolymorphicAssociation :
        owner = owner.proxy_target if owner.respond_to?(:proxy_target)

        update_method = :update_attachment_path_cache
        if owner.respond_to?(update_method)
          attr_name =
            if attachment.respond_to?(:proxy_reflection)
              attachment.proxy_reflection.name
            else
              # find the attachment reflection name (has_one :image, :class_name => 'Image') :
              reflection_name = nil
              owner.class.reflections.each do |name, reflection|
                if reflection.klass == attachment.class
                  reflection_name = name
                  break
                end
              end
              unless reflection_name
                raise "could not resolve attachment attr_name from reflections for #{owner.inspect}"
              end
              reflection_name
            end
          
          owner.send(update_method, attr_name, attachment)
        end
      end

      base.after_attachment_saved &update_cache_callback
      base.after_destroy &update_cache_callback
      ##

      base.extend ClassMethods
    end

    def has_thumbnail?(thumbnail)
      !!find_thumbnail(thumbnail)
    end

    def find_thumbnail(thumbnail)
      thumbnail_class.find_by_thumbnail_and_parent_id(thumbnail.to_s, id)
    end
    #alias_method :thumbnail, :find_thumbnail

    # NOTE: no need to perform this anymore as we validate the associated file 
    # by default with the owner ( has_attachment_file :validate => true ) !
    #def save(perform_validation = true)
    #  # need to fix attachment file saving, if called with
    #  # save(false) it does not get saved correctly e.g. thumb-nails
    #  # are not generated as some processing is hooked as
    #  # validation call-backs ... thus fix this behavior :
    #  unless perform_validation
    #    self.valid?
    #    self.errors.clear
    #  end
    #  super
    #end

    # override to have a custom message for "invalid" content type e.g. image validation
    # for error message translations @see ActiveRecord::Error::generate_message
    def attachment_attributes_valid?
      report_errors_on = self.class.read_inheritable_attribute(:report_errors_on)
      return super unless report_errors_on
      # :size :
      enum = attachment_options[:size]
      unless enum.nil? || enum.include?(size)
        errors.add report_errors_on, :file_size_invalid
      end
      # :content_type :
      enum = attachment_options[:content_type]
      unless enum.nil? || enum.include?(content_type)
        errors.add report_errors_on, :file_content_type_invalid
      end
    end
    
    # Helpers :

    def self.file_as_uploaded_data(file, content_type = nil)
      file = file.path if file.is_a?(File)
      file_data = {}
      fileio = StringIO.new
      File.open(file, 'rb') do |f|
        fileio << f.read
        file_data['size'] = f.stat.size
      end
      file_data['filename'] = File.basename(file)
      file_data['tempfile'] = fileio
      file_data['content_type'] = content_type || content_type_for(file)
      file_data
    end

    def self.build_attachment(owner, name, attributes)
      old_attachment = owner.send(name)
      unless old_attachment.nil?
        #owner.send("#{name}=", nil)
        old_attachment.destroy
      end
      owner.send("build_#{name}", attributes)
    end

    def self.create_attachment(owner, name, attributes)
      old_attachment = owner.send(name)
      owner.send("#{name}=", nil) # this is important as RoR keeps some _magick_
      # in its association proxies and thus the destroy won't work correctly ...
      new_attachment = owner.send("create_#{name}", attributes)
      if new_attachment.id && ! old_attachment.nil?
        old_attachment.destroy
      end
      new_attachment
    end

    def self.content_type_for(fname)
      if defined?(MIME::Types) # require 'mime/types' (mime-types gem)
        content_type = MIME::Types.type_for(fname).first # [ MIME ]
      else # fallback to Rails built-in Mime::Type
        extname = File.extname(fname).downcase[1..-1]
        content_type = Mime::Type.lookup_by_extension(extname)
      end
      content_type = content_type.first if content_type.is_a?(Array)
      raise "unknown content type for '#{fname}'" unless content_type
      content_type.to_s # #<MIME::Type:...>.to_s OR #<Mime::Type:...>.to_s
    end

    module ClassMethods

      # an extended version of has_attachment :
      # - adds "filename" support for :db_file storage
      def has_attachment(options = {})
        # if 'overriden' include what's already here
        super(attachment_options.merge(options))
        if attachment_options[:storage] == :db_file
          require 'attachment_fx/db_file_helpers'
          mod = AttachmentFx::DbFileHelpers
          send :include, mod unless included_modules.include?(mod)
        end
      end

      def path_prefix
        attachment_options[:path_prefix]
      end

      def validates_as_attachment(report_errors_on = nil)
        write_inheritable_attribute :report_errors_on, report_errors_on
        super() # attachment_fu method does :
        # validates_presence_of :size, :content_type, :filename
        # validate              :attachment_attributes_valid?
      end

      def new_from_file(file)
        self.new :uploaded_data => file_as_uploaded_data(file)
      end

      delegate :file_as_uploaded_data,
               :build_attachment,
               :create_attachment,
               :content_type_for,
               :to => AttachmentFile
      
    end

  end
end