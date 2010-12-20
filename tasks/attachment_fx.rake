
namespace :attachment_fx do

  desc "Updates the attachment_path_cache for all models having an attachment" +
       " (use MODELS=User,Role to limit model classes)"
  task :update_path_cache => :environment do
    attachment_owner_classes_with_path_cache do |owner_class|
      puts "updating #{owner_class.count} #{owner_class} instances"
      send_all(owner_class, :update_attachment_path_cache)
    end
  end

  desc "Updates the attachment_path_cache for all models having an attachment" +
       " (use MODELS=User,Role to limit model classes; HOSTS to specify host ids)"
  task :expire_path_cache => :environment do
    attachment_owner_classes_with_path_cache do |owner_class|
      puts "expiring #{owner_class.count} #{owner_class} instances"
      send_all(owner_class, :expire_attachment_path_cache, hosts)
    end
  end

  def send_all(klass, method, *args)
    limit = (ENV['LIMIT'] || 1000).to_i
    left = klass.count; offset = 0
    while left > 0
      instances = klass.find(:all, :limit => limit, :offset => offset)
      instances.each { |instance| instance.send(method, *args) }
      left -= limit; offset += limit
    end
  end

  def hosts
    if hosts = ENV['HOSTS']
      hosts == 'all' ? :all : hosts.split(',')
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
    require 'set'
    klasses = Set.new
    
    model_names.each do |model_name|
      class_name = model_name.sub(/\.rb$/,'').camelize
      begin
        klass = class_name.split('::').inject(Object) do |klass, part|
          klass.const_get(part)
        end
        if klass < ActiveRecord::Base && ! klass.abstract_class? &&
           klass.include?(AttachmentFx::Owner)
         klasses.add(klass)
        else
          #puts "skipping #{class_name}"
        end
      rescue Exception => e
        puts "#{class_name}: #{e.message}"
      end
    end

    if block_given?
      klasses.each { |klass| yield(klass) }
    else
      klasses
    end
  end

  def attachment_owner_classes_with_path_cache
    attr_name = AttachmentFx::Owner::PathCache.attachment_path_cache_attr_name
    attachment_owner_classes do |klass|
      if klass.include?(AttachmentFx::Owner::PathCache) &&
       if klass.column_names.include?(attr_name.to_s) ||
          klass.instance_methods.include?(attr_name.to_s)
         yield(klass)
       end
      end
    end
  end

end
