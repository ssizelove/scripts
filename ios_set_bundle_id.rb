#!/usr/bin/env ruby
require 'xcodeproj'

proj_path = File.expand_path(ARGV[0] || '')
bundle_id = ARGV[1]

if proj_path.empty? || bundle_id.nil? || bundle_id.strip.empty?
  abort "usage: #{File.basename($0)} <path-to-Runner.xcodeproj> <bundleId>"
end
abort "not found: #{proj_path}" unless File.exist?(proj_path)

p = Xcodeproj::Project.open(proj_path)
t = p.targets.find { |x| x.name == 'Runner' } or abort "Runner target not found"
t.build_configurations.each { |cfg| cfg.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id }
p.save
puts "✅ Set PRODUCT_BUNDLE_IDENTIFIER=#{bundle_id} for Runner (all configs)"
