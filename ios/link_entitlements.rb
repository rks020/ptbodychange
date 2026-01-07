
require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 1. Add file to project
file_name = 'Runner.entitlements'
group = project.main_group.find_subpath(File.join('Runner'), true)
file_ref = group.files.find { |f| f.path == file_name } || group.new_file(file_name)

# 2. Add CODE_SIGN_ENTITLEMENTS to Build Settings
project.targets.each do |target|
  if target.name == 'Runner'
    target.build_configurations.each do |config|
      config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
    end
  end
end

project.save
puts "Entitlements linked successfully."
