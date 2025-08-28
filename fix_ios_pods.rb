#!/usr/bin/env ruby
# Usage: ruby fix_ios_pods.rb
# Run from your Flutter project root (same place as pubspec.yaml).

require 'fileutils'
require 'xcodeproj'

proj_path = 'ios/Runner.xcodeproj'
xcconfigs = {
  'Debug'   => 'ios/Flutter/Debug.xcconfig',
  'Profile' => 'ios/Flutter/Profile.xcconfig',
  'Release' => 'ios/Flutter/Release.xcconfig'
}

# Ensure xcconfigs exist with correct includes
xcconfigs.each do |name, path|
  dir = File.dirname(path)
  FileUtils.mkdir_p(dir)
  podfile = "../Pods/Target Support Files/Pods-Runner/Pods-Runner.#{name.downcase}.xcconfig"
  contents = [
    %(#include? "#{podfile}"),
    %(#include? "Generated.xcconfig")
  ]
  File.write(path, contents.join("\n") + "\n")
end

# Open project and set base configurations
project = Xcodeproj::Project.open(proj_path)
target = project.targets.find { |t| t.name == 'Runner' } or abort("Runner target not found")

xcconfigs.each do |name, path|
  file_ref = project.files.find { |f| f.path == path.sub('ios/', '') }
  file_ref ||= project.new_file(path.sub('ios/', ''))
  cfg = target.build_configurations.find { |c| c.name == name }
  cfg.base_configuration_reference = file_ref if cfg
end

project.save
puts "✅ iOS Base Configurations fixed. You can now run 'cd ios && pod install'."
