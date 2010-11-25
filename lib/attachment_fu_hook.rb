
Technoweenie::AttachmentFu::ActMethods.class_eval do

  def has_attachment_with_attachment_fx(options = {})
    has_attachment_without_attachment_fx(options) # super

    fx_mod = AttachmentFx::AttachmentFile
    include fx_mod unless included_modules.include?(fx_mod)
  end

  alias_method_chain :has_attachment, :attachment_fx

end
