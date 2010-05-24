ActiveRecord::Schema.define(:version => 0) do

  create_table :attachment_files, :force => true do |t|
    t.string  :"type"
    t.integer :"parent_id"
    t.string  :"thumbnail"
    t.integer :"db_file_id"
    t.string  :"filename"
    t.integer :"size"
    t.string  :"content_type"
    t.integer :"width"
    t.integer :"height"
    t.integer :"owner_id"
    t.string  :"owner_type"
    t.string  :"owner_meta"
  end

  create_table :db_files, :force => true do |t|
    t.column :data, :binary
  end

  create_table :image_owners, :force => true do |t|
    t.string  :name
  end

  create_table :validated_image_owners, :force => true do |t|
    t.string  :name
  end

  create_table :image_owners_with_path_cache, :force => true do |t|
    t.string  :name
    t.text    :attachment_path_cache
  end

#  create_table :minimal_attachments, :force => true do |t|
#    t.column :size,            :integer
#    t.column :content_type,    :string, :limit => 255
#  end

end
