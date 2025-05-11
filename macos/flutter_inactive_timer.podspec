#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_inactive_timer.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_inactive_timer'
  s.version          = '1.1.1'
  s.summary          = 'A Flutter plugin for detecting user inactivity in desktop applications.'
  s.description      = <<-DESC
A Flutter plugin for detecting user inactivity in desktop applications (Windows and macOS). 
This plugin provides customizable timeout and notification thresholds, making it ideal for 
implementing security features like automatic logout or session timeouts.
                       DESC
  s.homepage         = 'https://github.com/kihyun1998/flutter_inactive_timer'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'kihyun1998' => 'https://github.com/kihyun1998' }

  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'

  # Uncommented the privacy manifest resources since macOS might need it for input monitoring
  s.resource_bundles = {'flutter_inactive_timer_privacy' => ['Resources/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.14'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end