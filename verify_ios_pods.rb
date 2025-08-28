#!/usr/bin/env ruby
require 'xcodeproj'

def fail!(msg)  abort("❌ #{msg}") end
fail!("run from project root (pubspec.yaml missing)") unless File.exist?('pubspec.yaml')
fail!("iOS project missing (ios/Runner.xcodeproj)")   unless File.exist?('ios/Runner.xcodeproj')

# 1) show base configs on Runner target
p = Xcodeproj::Project.open('ios/Runner.xcodeproj')
t = p.targets.find { |x| x.name == 'Runner' } or fail!("Runner target not found")
puts "▶ Base Configurations (Runner target):"
t.build_configurations.each do |cfg|
  ref  = cfg.base_configuration_reference
  path = ref&.path || '(none)'
  puts "  #{cfg.name.ljust(7)} -> #{path}"
end

# 2) verify xcconfig contents (2 lines, with correct includes)
def ok_xc(path, flavor)
  want = [
    %(#include? "../Pods/Target Support Files/Pods-Runner/Pods-Runner.#{flavor}.xcconfig"),
    %(#include? "Generated.xcconfig")
  ]
  if !File.exist?(path)
    puts "  ⚠ missing #{path}"
    return false
  end
  lines = File.read(path).lines.map(&:strip).reject(&:empty?)
  good  = (lines[0] == want[0] && lines[1] == want[1])
  puts "  #{path}: #{good ? 'OK' : '⚠ not canonical (first two lines differ)'}"
  good
end

puts "▶ xcconfig checks:"
d_ok = ok_xc('ios/Flutter/Debug.xcconfig',   'debug')
p_ok = ok_xc('ios/Flutter/Profile.xcconfig', 'profile')
r_ok = ok_xc('ios/Flutter/Release.xcconfig', 'release')

# 3) verify Pods support xcconfigs exist (after `pod install`)
pod_dir = 'ios/Pods/Target Support Files/Pods-Runner'
want_pods = %w[debug profile release].map { |f| File.join(pod_dir, "Pods-Runner.#{f}.xcconfig") }
puts "▶ Pods support files:"
want_pods.each do |f|
  puts "  #{f}: #{File.exist?(f) ? 'OK' : '⚠ missing (run: cd ios && pod install)'}"
end

# exit with nonzero if anything looks off (useful in CI)
exit 1 unless d_ok && p_ok && r_ok && want_pods.all? { |f| File.exist?(f) }
puts "✅ verification passed"
