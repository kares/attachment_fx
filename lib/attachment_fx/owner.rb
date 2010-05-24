
module AttachmentFx
  
  #
  # will get included into the attachment file "owner"
  # each and every attachment file belongs_to an owner
  #
  module Owner

    # enable acting as "regular" attribute :
    #
    # user.update_attributes :name => 'Karol Bucek',
    #                        :photo => { :uploaded_data => StringIO }
    #
    def attributes=(attributes)
      set_attachments(attachment_assigns(attributes))
      super(attributes)
    end

    def save(validate = true)
      invalid_attachments = attachments_with_errors(validate && new_record?)
      return false if validate && ! valid?
      if new_record?
        # thus when creating a new owner with attachments it
        # won't get saved until all attachments are valid :
        invalid_attachments.blank? && super
      else
        # if updating an owner it's ok to update owner attributes
        # but should report false if any attachment is invalid :
        super && invalid_attachments.blank?
      end
    end

    protected

      def attachment?(name)
        attachment = self.send(name)
        ! attachment.nil? && ! attachment.new_record?
      end

      def attachment_path(name, thumb)
        self.send(name).public_filename(thumb)
      end

      def attachment_full_path(name, thumb)
        self.send(name).full_filename(thumb)
      end

    private

      def attachments_with_errors(validate = false)
        self.class.attachment_attr_names.inject([]) do |array, name|
          unless (attachment = self.send(name)).nil?
            attachment.valid? if validate # run the validations
            array << attachment unless attachment.errors.blank?
          end
          array
        end
      end

      def set_attachments(names)
        names.each do |name, attachment_attrs|
          set_attachment(name, attachment_attrs)
        end
      end

      def set_attachment(name, attributes)
        if new_record?
          file = send :"build_#{name}", attributes
          send :"set_#{name}_target", file
        else
          AttachmentFile.create_attachment(self, name, attributes) # TODO seems desired ?!
        end
      end

      def attachment_assigns(attributes)
        self.class.attachment_attr_names.map do |name|
          if attributes[name] && attributes[name].is_a?(Hash)
            [ name, attributes.delete(name) ]
          else
            nil
          end
        end.compact
      end

    #
    # caching for attachment_path (and attachment?) e.g. :
    #
    # class User
    #   has_attachment_file :photo
    # end
    #
    # user = User.find ...
    # user.has_photo? # will be cached
    # user.photo_path # will be cached
    #
    # caching uses an owner attribute e.g. in the User case the users
    # table is expected to contain an 'attachment_path_cache' column,
    # thus the attachment file association does not need to be loaded.
    #
    module PathCache

      @@attachment_path_cache_attr_name = :attachment_path_cache
      mattr_accessor :attachment_path_cache_attr_name

      def self.included(base)
        attr_name = attachment_path_cache_attr_name
        if base.column_names.include?(attr_name.to_s) ||
           base.instance_methods.include?(attr_name.to_s)
          base.send :serialize, attr_name.to_sym
        else
          RAILS_DEFAULT_LOGGER.info "consider adding a '#{attr_name}' column for " +
                                    "#{self} to cache attachment '*_path' methods"
        end
      end

  #    def self.setup_cache_update(base, attachment_attr_name, attachment_class_name)
  #      update_method = :update_attachment_path_cache
  #      return unless base.instance_methods.include? update_method.to_s
  #      update_cache_callback = Proc.new do |attachment|
  #        attachment.owner.send(update_method, attachment_attr_name, attachment) if attachment.owner
  #      end
  #      attachment_class = attachment_class_name.constantize
  #      attachment_class.send :after_attachment_saved, &update_cache_callback
  #      attachment_class.send :after_destroy, &update_cache_callback
  #    end

      # AttachmentFile::Owner overrides :

      def attachment?(name)
        if respond_to? cache_attr_name = attachment_path_cache_attr_name
          if path_cache = send(cache_attr_name)
            name_s = name.to_s
            if path_cache.has_key?(name_s)
              return !! path_cache[name_s]
            end
          end
        end
        super
      end

      def attachment_path(name, thumb)
        if respond_to? cache_attr_name = attachment_path_cache_attr_name
          path_cache = send cache_attr_name
          path_cache = {} unless path_cache

          name_s = name.to_s
          if path_cache.has_key?(name_s)
            name_cache = path_cache[name_s]
            return '' unless name_cache # nil
          else # not yet cached :
            name_cache = path_cache[name_s] = {}
          end

          thumb_s = thumb.to_s # nil.to_s == ''
          return name_cache[thumb_s] if name_cache[thumb_s]

          returning super do |path|
            name_cache[thumb_s] = path
            update_attachment_path_cache_attribute(path_cache)
          end
        end
        super
      end

      def attachment_full_path(name, thumb)
        File.expand_path(attachment_path(name, thumb), AttachmentFx::PUBLIC_PATH)
      end

      protected

        def update_attachment_path_cache(attr_name = nil, attachment = nil)
          if respond_to? cache_attr_name = attachment_path_cache_attr_name
            path_cache = send cache_attr_name
            path_cache = {} unless path_cache

            update_path_cache_for_attachment = Proc.new do |name, instance|
              
              #puts "update_attachment_path_cache() name = #{name} attachment = #{instance}"
              #puts "update_attachment_path_cache() destroyed = #{instance.destroyed?}" if instance

              if instance.nil? || instance.destroyed?
                path_cache[name.to_s] = nil
              else # we're going to cache the public_filename :
                unless name_cache = path_cache[name = name.to_s]
                  name_cache = path_cache[name] = {}
                end
                if thumb = instance[:thumbnail] # it's a thumbnail
                  name_cache[thumb.to_s] = instance.public_filename
                else # it's the parrent (might have thumbnails) :
                  name_cache[''] = instance.public_filename
                  instance.thumbnails.each do |attachment_thumb|
                    thumb = attachment_thumb[:thumbnail].to_s # thumbnail name
                    name_cache[thumb] = instance.public_filename(thumb.to_sym)
                  end if instance.thumbnailable?
                end
              end
            end

            if attr_name # single update :
              attach = attachment ? attachment : send(attr_name)
              update_path_cache_for_attachment.call(attr_name, attach)
            else # update all attachments :
              self.class.attachment_attr_names.each do |_attr_name|
                attach = send(_attr_name)
                #if ! attach.nil? || attach.respond_to?(:public_filename)
                update_path_cache_for_attachment.call(_attr_name, attach)
                #end
              end
            end

            #puts "update_attachment_path_cache() path_cache = #{path_cache.inspect}"

            update_attachment_path_cache_attribute(path_cache)
          end
        end

        def expire_attachment_path_cache
          if respond_to? attachment_path_cache_attr_name
            update_attachment_path_cache_attribute(nil)
          end
        end

        def update_attachment_path_cache_attribute(path_cache)
          cache_attr_name = attachment_path_cache_attr_name
          #update_attribute(cache_attr_name, path_cache)
          send("#{cache_attr_name}=", path_cache)
          save(false) unless readonly?
        end

    end

  end
end