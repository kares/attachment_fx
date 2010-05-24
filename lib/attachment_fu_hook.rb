
Technoweenie::AttachmentFu::ActMethods.class_eval do

  def has_attachment_with_attachment_fx(options = {})
    has_attachment_without_attachment_fx(options) # super

    fx_module = AttachmentFx::AttachmentFile
    include fx_module unless included_modules.include?(fx_module)
  end

  alias_method_chain :has_attachment, :attachment_fx

end
