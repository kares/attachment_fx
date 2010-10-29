unless defined? Technoweenie::AttachmentFu
  raise "attachment_fu not present - this means it's either not installed " +
        "or it's not yet loaded (change the plugins loading order)"
end

module AttachmentFx

  PUBLIC_PATH = if defined? ActionView::Helpers::AssetTagHelper::ASSETS_DIR
    ActionView::Helpers::AssetTagHelper::ASSETS_DIR
  else
    File.join(RAILS_ROOT, 'public')
  end

end

require 'attachment_fx/attachment_file'
require 'attachment_fx/owner'

require 'attachment_fu_hook'

module AttachmentFx

  PATH_CACHE_ENABLED = true

  #
  # ActMethods for all ARs this is complementary to the AttachmentFu::ActMethods !
  #
  # attachment_fu provided us with a has_attachment method
  #
  # this act provides a has_attachment_file method which declares a caller
  # (owner) to "have one" AttachmentFile (or it's subclass) association !
  #
  module ActMethods

    # has_one :photo, :as => :owner, :class_name => 'User::Photo', :dependent => :destroy
    #  to
    # has_attachment_file :photo
    def has_attachment_file(association_id, options = {})
      options[:as] = :owner unless options.has_key?(:as)
      if options[:class_name]
        current, clazz = options[:conditions], options[:class_name]
        options[:conditions] = merge_conditions(current, "type = '#{clazz}'")
      else
        # try to auto-detect custom class name :
        const_name = association_id.to_s.camelize # :photo -> Photo
        options[:class_name] =
          if self.const_defined?(const_name) # User.const_defined? Photo
            "#{self.name}::#{const_name}" # User::Photo
          elsif Object.const_defined?(const_name) # Object.const_defined? Photo
            const_name # Photo
          else
            raise ":class_name not provided and could not auto-resolve " + 
                  "#{const_name} class constant in Object or #{self}"
          end
      end

      options[:autosave] = true unless options.has_key?(:autosave)
      options[:validate] = true unless options.has_key?(:validate)
      # this will only work with Rails 2.3.6+ :
      options[:inverse_of] = :owner unless options.has_key?(:inverse_of)
      # do not keep orphan attachments by default :
      options[:dependent] = :destroy unless options.has_key?(:dependent)

      has_one association_id, options

      mod = AttachmentFx::Owner
      include(mod) unless include?(mod)

      write_inheritable_array(:attachment_attr_names, [ association_id.to_sym ])

      self.class_eval(%Q{
        def has_#{association_id}?
          attachment?(:'#{association_id}')
        end

        def #{association_id}_path(thumb = nil)
          attachment_path(:'#{association_id}', thumb)
        end

        def #{association_id}_full_path(thumb = nil)
          attachment_full_path(:'#{association_id}', thumb)
        end
      }, __FILE__, __LINE__)

      if PATH_CACHE_ENABLED
        mod = AttachmentFx::Owner::PathCache
        include(mod) unless include?(mod)
      end
    end

    # returns all attachment file association names for this class
    def attachment_attr_names
      read_inheritable_attribute(:attachment_attr_names)
    end

  #  def attachment_class_name(name)
  #    unless attachment_attr_names.include?(name)
  #      raise "#{name} is not an attachment attr name !"
  #    end
  #    reflection = self.reflections[name.to_sym]
  #    reflection.options[:class_name]
  #  end

  end
end

ActiveRecord::Base.send :extend, AttachmentFx::ActMethods
