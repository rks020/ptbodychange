
require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 1. Find the Runner entry in the Project Navigator
runner_group = project.main_group.find_subpath(File.join('Runner'), true)

# 2. Add the file reference if it doesn't exist
file_name = 'GoogleService-Info.plist'
file_ref = runner_group.files.find { |f| f.path == file_name }
unless file_ref
  puts "Adding #{file_name} to Runner group..."
  file_ref = runner_group.new_file(file_name)
end

# 3. Find the main target (Runner)
target = project.targets.find { |t| t.name == 'Runner' }

# 4. Add to 'Copy Bundle Resources' build phase
resources_phase = target.resources_build_phase
build_file = resources_phase.files.find { |f| f.file_ref && f.file_ref.path == file_name }

unless build_file
  puts "Adding #{file_name} to Copy Bundle Resources..."
  resources_phase.add_file_reference(file_ref)
  project.save
  puts "Project saved successfully."
else
  puts "#{file_name} is already in Copy Bundle Resources."
end
