#
# Be sure to run `pod lib lint Kitemetrics.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |spec|
  spec.name             = 'Kitemetrics'
  spec.version          = '1.2.1'
  spec.summary          = 'iOS App Analytics, Apple Search Ads Attribution, and Reporting.'
  
  spec.swift_version    = '5.3.3'
  spec.ios.deployment_target = '9.0'

  spec.description      = <<-DESC
Kitemetrics provides keyword level attribution for Apple Search Ads. It associates each attribution to an In-App Purchase. The Kitemetrics web service calculates the Average Revenue per User.
                       DESC

  spec.homepage         = 'https://github.com/kitefaster/kitemetrics_iOS'
  # spec.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  spec.license          = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
  spec.author           = { 'Kitemetrics' => '' }
  spec.source           = { :git => 'https://github.com/kitefaster/kitemetrics_iOS.git', :tag => spec.version.to_s }
  spec.social_media_url = 'https://twitter.com/kitefasterApps'

  spec.source_files    = 'Kitemetrics/Classes/**/*'
  spec.weak_framework  = 'iAd'
  
  spec.dependency 'ReachabilitySwift', '~> 5.0.0'
  spec.dependency 'SwiftyBeaver'
  
end
