
namespace :attachment_fx do

  desc "Updates the attachment_path_cache for all models having an attachment" +
       " (use MODELS=User,Role to limit model classes)"
  task :update_path_cache => :environment do
    attachment_owner_classes do |owner_class|
      owner_instances = owner_class.all
      puts "updating #{owner_instances.size} #{owner_class} instances"
      owner_instances.each do |owner|
        owner.send :update_attachment_path_cache
      end
    end
  end

  desc "Updates the attachment_path_cache for all models having an attachment" +
       " (use MODELS=User,Role to limit model classes)"
  task :expire_path_cache => :environment do
    attachment_owner_classes do |owner_class|
      owner_instances = owner_class.all
      puts "expiring #{owner_instances.size} #{owner_class} instances"
      owner_instances.each do |owner|
        owner.send :expire_attachment_path_cache
      end
    end
  end

  # If we have command line argument MODELS=xxx they're assumed to be the model
  # class names, otherwise we take all the model files under app/models dir ...
  def model_names
    models = (ENV['MODELS'] || '').split(',')
    if models.empty? && ! ENV['MODELS'] # all models :
      Dir.chdir(File.join(RAILS_ROOT, 'app/models')) do
        models = Dir["**/*.rb"]
      end
    end
    models
  end

  # Walk through/return all the attachment owner models.
  def attachment_owner_classes
    model_names.each do |model_name|
      class_name = model_name.sub(/\.rb$/,'').camelize
      begin
        klass = class_name.split('::').inject(Object) do |klass, part|
          klass.const_get(part)
        end
        if klass < ActiveRecord::Base && ! klass.abstract_class? &&
           klass.include?(AttachmentFx::Owner::PathCache)
          yield(klass)
        else
          #puts "skipping #{class_name}"
        end
      rescue Exception => e
        puts "Unable to update #{class_name}: #{e.message}"
      end
    end
  end

end
