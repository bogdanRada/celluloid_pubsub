# module that is used for formatting numbers using metrics
module Helper
# function that makes the methods incapsulated as utility functions

module_function

  def find_loaded_gem_property(name, property)
    gem_obj = Gem.loaded_specs.values.find { |repo| repo.name == name }
    gem_obj.respond_to?(property) ? gem_obj.send(property) : nil
  end

  def celluloid_version(options)
    version = find_loaded_gem_property('celluloid', 'version')
    Versionomy.parse(version.to_s).unparse(options)
  end

  def verify_celluloid_version(version_number, operator, options)
    final_version = celluloid_version(options)
    parsed_version = Versionomy.parse(version_number)
    final_version.send(operator, parsed_version)
  rescue Versionomy::Errors::ParseError
    false
  end
end
