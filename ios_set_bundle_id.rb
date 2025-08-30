#!/usr/bin/env ruby
require 'xcodeproj'

proj_path = File.expand_path(ARGV[0] || 'ios/Runner.xcodeproj')
bundle_id = ARGV[1] || 'com.sizelove.adhdapp'
abort "Usage: ios_set_bundle_id.rb <path-to-Runner.xcodeproj> <bundleId>" unless File.exist?(proj_path)

p = Xcodeproj::Project.open(proj_path)
target = p.targets.find { |t| t.name == 'Runner' } or abort "Runner target not found"

target.build_configurations.each do |cfg|
  cfg.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
end

p.save
puts "✅ Set PRODUCT_BUNDLE_IDENTIFIER=#{bundle_id} for target Runner (all configs)"
