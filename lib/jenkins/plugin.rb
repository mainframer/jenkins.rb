
require 'pathname'

module Jenkins
  # Acts as the primary gateway between Ruby and Jenkins
  # There is one instance of this object for the entire
  # plugin
  #
  # On the Java side, it contains a reference to an instance
  # of RubyPlugin. These two objects talk to each other to
  # get things done.
  #
  # Each running ruby plugin has exactly one instance of
  # `Jenkins::Plugin`
  class Plugin

    # A list of all the hudson.model.Descriptor objects
    # of which this plugin is aware *indexed by Wrapper class*
    #
    # This is used so that wrappers can always have a single place
    # to go when they are asked for a descriptor. That way, wrapper
    # instances can always return the descriptor associated with
    # their class.
    #
    # This may go away.
    attr_reader :descriptors

    # the instance of jenkins.ruby.RubyPlugin with which this Plugin is associated
    attr_reader :peer

    # Initializes this plugin by reading the models.rb
    # file. This is a manual registration process
    # Where ruby objects register themselves with the plugin
    # In the future, this process will be automatic, but
    # I haven't decided the best way to do this yet.
    #
    # @param [org.jenkinsci.ruby.RubyPlugin] java a native java RubyPlugin
    def initialize(java)
      @java = @peer = java
      @start = @stop = proc {}
      @descriptors = {}
      @proxies = Proxies.new(self)
    end

    # Initialize the singleton instance that will run for a
    # ruby plugin. This method is designed to be called by the
    # Java side when setting up the ruby plugin
    # @return [Jenkins::Plugin] the singleton instance
    def self.initialize(java)
      #TODO: check for double initialization?!?
      @instance = new(java)
      @instance.load_models
      return @instance
    end

    # Get the singleton instance associated with this plugin
    #
    # This is useful when code in the plugin needs to get a
    # reference to the plugin in which it is running e.g.
    #
    #     Jenkins::Plugin.instance #=> the running plugin
    #
    # @return [Jenkins::Plugin] the singleton instance
    def self.instance
      @instance
    end

    # Register a ruby class as a Jenkins extension point of
    # a particular java type
    #
    # This method is invoked automatically as part of the auto-registration
    # process, and should not need to be invoked by plugin code.
    #
    # @param [Class] ruby_class the class implementing the extension point
    # @param [java.lang.Class] java_class that Jenkins will see this extention point as
    def register_describable(ruby_class, java_class)
      descriptor = Jenkins::Model::Descriptor.new(ruby_class, self, java_class)
      @peer.addExtension(descriptor)
      @descriptors[ruby_class] = descriptor
    end

    # unique identifier for this plugin in the Jenkins server
    def name
      @peer.getWrapper().getShortName()
    end

    # Called once when Jenkins first initializes this plugin
    # currently does nothing, but plugin startup hooks would
    # go here.
    def start
      @start.call()
    end

    # Called one by Jenkins (via RubyPlugin) when this plugin
    # is shut down. Currently this does nothing, but plugin
    # shutdown hooks would go here.
    def stop
      @stop.call()
    end

    # Reflect an Java object coming from Jenkins into the context of this plugin
    # If the object is originally from the ruby plugin, and it was previously
    # exported, then it will unwrap it. Otherwise, it will just use the object
    # as a normal Java object.
    #
    # @param [Object] object the object to bring in from the outside
    # @return the best representation of that object for this plugin
    def import(object)
      @proxies.import object
    end

    # Reflect a native Ruby object into its External Java form.
    #
    # Delegates to `Proxies` for the heavy lifting.
    #
    # @param [Object] object the object
    # @returns [java.lang.Object] the Java proxy
    def export(object)
      @proxies.export object
    end

    # Link a plugin-local Ruby object to an external Java object.
    #
    # see 'Proxies#link`
    #
    # @param [Object] internal the object on the Ruby side of the link
    # @param [java.lang.Object] external the object on the Java side of the link
    def link(internal, external)
      @proxies.link internal, external
    end

    def load_models
      p = @java.getModelsPath().getPath()
      puts "Trying to load models from #{p}"
      for filename in Dir["#{p}/**/*.rb"]
        puts "Loading "+filename
        load filename
      end
    end
  end
end