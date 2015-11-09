# module that is used for formatting numbers using metrics
module Helper
# function that makes the methods incapsulated as utility functions

def celluloid_path
 Bundler.rubygems.find_name('celluloid').first.full_gem_path
end

def celluloid_version
  File.basename(celluloid_path).gsub("celluloid-", '')
end

def verify_celluloid_version(version_number, operator, options)
  parsed_version = Versionomy.parse(version_number)
  final_version = Versionomy.parse(celluloid_version.to_s)
  final_version.unparse(options)
  final_version.send(operator,  parsed_version)
rescue Versionomy::Errors::ParseError
  false
end


end
