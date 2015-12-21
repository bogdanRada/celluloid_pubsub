# module used for feching gem information
module Helper
  # function that makes the methods incapsulated as utility functions

  module_function

  def find_loaded_gem_property(gem_name, property)
    gem_spec = Gem.loaded_specs.values.find { |repo| repo.name == gem_name }
    gem_spec.respond_to?(property) ? gem_spec.send(property) : nil
  end

  def fetch_gem_version(gem_name)
    version = find_loaded_gem_property(gem_name, 'version')
    version.blank? ? nil : get_parsed_version(version)
  end

  def get_parsed_version(version)
    version = version.to_s.split('.')
    version.pop until version.size == 2
    Versionomy.parse(version.join('.'))
  rescue Versionomy::Errors::ParseError
    nil
  end

  def verify_gem_version(gem_name, version, options = {})
    options.stringify_keys!
    version = get_parsed_version(version)
    gem_version = fetch_gem_version(gem_name)
    gem_version.blank? ? false : gem_version.send(options.fetch('operator', '<='), version)
  end

end
