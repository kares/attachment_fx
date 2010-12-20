AttachmentFx
============

An *attachment_fu* eXtension.

Adds useful attachment helper methods to the owning model, such as:
`user.has_photo?` and `user.photo_path`.

Extends the file interface for the `:db_file` backend (@see *attachment_fu*
`:storage` option). The database backend interface mimics the `:file_system`
storage, the db data is on-demand downloaded into the public directory (the
target path prefix is customizable with the `:path_prefix` option).


Setup
=====

Make sure You have the *attachment_fu* plugin installed :

    script/plugin install git://github.com/technoweenie/attachment_fu.git

AttachmnetFu seems a little retired these days, however there are number of
forks fixing deprecation warnings and issues with newer Rails, try mine :

    script/plugin install git://github.com/kares/attachment_fu.git

Finally, install *attachment_fx* as a plain old Ruby on Rails plugin :

    script/plugin install git://github.com/kares/attachment_fx.git

**NOTE:** If You've adjusted the plugins loading order make sure *attachment_fx*
loads after *attachment_fu* !


Usage
=====

Setup a shared meta-data model (as advised by *attachment_fu*) with sensible
`has_attachment` defaults (so one does not have to redeclare the `:storage`, 
`:processor` etc options for inherited attachment models) e.g. :

    class AttachmentFile < ActiveRecord::Base

      has_attachment :storage => :db_file,
                     :path_prefix => "public/files",
                     :processor => :MiniMagick

    end

This should be a base (polymorphic) attachment class one would extend, and is
setup to belong to a "owner" class, that will own attachments of a given type.

Next we declare the "owner" model having an attachment file :

    class User < ActiveRecord::Base

      has_attachment_file :photo

    end

Now the polymorphism kicks in, it will attempt to resolve a `Photo` class that
might look just like a plain old (*attachment_fu*) attachment :

    class User::Photo < AttachmentFile

      has_attachment :content_type => :image,
                     :resize_to => '96x96c',
                     :thumbnail_class => self,
                     :thumbnails => { :small => '48x48' }

    end

We already have some (not just for testing) useful helpers :

    User::Photo.new_from_file('../avatars/default.jpg').save!

    photo_data = AttachmentFile.file_as_uploaded_data '../avatars/default.jpg'
    user.build_photo :uploaded_data => photo_data

Resolving file content types for these helpers is based on passing the file
extension to the *mime-types* gem, if the gem is not available it will fallback
to the Rails built-in `Mime::Type` which is not primarily designed for resolving
file types from their .ext but is usable if it has been setup correctly
(@see the *mime_types* initializer).

As we're using `:storage => :db_file` one might expect all the nifty interface
as if one used `:storage => :file_system` e.g. :

    user.photo.public_filename

    user.photo.full_filename(:small)

Files will be downloaded on-demand from the DB and stored based on the
`:path_prefix` attachment option.

NOTE: If You're using the `:db_file` backed do not forget to set it up in Your
migrations. Your meta-data table (in this example `attachment_files`) requires a
`db_file_id` foreign key to the `db_files` storage table (@see the [fu wiki](http://github.com/technoweenie/attachment_fu/wiki)).

If You've setup Your `db_files` table data column as `:binary` and You're using
**MySQL** You might run into a **64kB** limit (RoR `:binary` equals a simple DB
**BLOB**).
So in order to save bigger files one should use **LONGBLOB**, migrate with :

    connection.execute("ALTER TABLE db_files CHANGE `data` `data` LONGBLOB")


### has_attachment_file

This helper is a shortcut to declare a *has_one* association to the attachment.
It does setup sensible defaults, owner methods and some lifecycle callbacks, It
accepts all the options of [has_one](http://apidock.com/rails/ActiveRecord/Associations/ClassMethods/has_one).
The `has_attachment_file :photo` example translates as follows :

    has_one :photo, :as => :owner, 
            :class_name => 'User::Photo' || 'Photo',
            :autosave => true,
            :validate => true,
            :dependent => :destroy,
            :inverse_of => :owner


### Owner Methods

Attachments are treated, and should act, as if they were regular attributes (
although they are in the very detail `has_one` associations), there are 3 helper
methods being added to the owner class, for each attachment file it declares to
have, to help them feel more natural.
For example the above `User` class would setup these instance methods :

    user.has_photo?

    user.photo_path(:small)

    user.photo_full_path


### Path Caching

Using the above owner methods, You will soon discover that most of the time those
are all You really need for displaying attachments in web pages. It's pretty
useless to load the association every time one needs a public file path in a HTML
image tag.

Migrating Your attachment owner models to contain a `attachment_path_cache` column
allows You to cache paths for all attachments attached to the given model, thus
not loading the associations unless necessary. Sample migration :

    class AddAttachmentPathCacheColumns < ActiveRecord::Migration

      def self.up
        add_column :users, :attachment_path_cache, :text, :default => nil
      end

      def self.down
        remove_column :users, :attachment_path_cache
      end

    end

Now as long as You're using the owner `has_photo?` and `photo_path` methods from
a user instance these won't load the `photo` association after the path has been
cached and saved (unless of course You're manipulating the attachment).

**NOTE:** This will work in ditributed setups (multiple hosts involved) except
for deleting attachments. Only the host deleting the record cleans up the related
public file paths from the file system. For a single host deployment one can
easily disable this functionality (saving one serialized hash per record) :

     AttachmentFx::Owner::PathCache.host_id = nil # put this in an initializer

There are *rake* tasks for updating/expiring path caches in case needed :

    rake attachment_fx:update_path_cache MODELS=User,Post
    rake attachment_fx:expire_path_cache HOSTS=all


AttachmentFu
------------

<http://github.com/technoweenie/attachment_fu>

attachment_fu facilitates file uploads in Ruby on Rails.
There are a few storage options for the actual file data, but the plugin always
at a minimum stores metadata for each file in the database.

[AttachmentFu LICENSE](LICENSE.attachment_fu)
