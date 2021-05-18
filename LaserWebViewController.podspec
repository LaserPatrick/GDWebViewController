
Pod::Spec.new do |s|
  s.name              = "LaserWebViewController"
  s.version           = "2.0.2"
  s.summary           = "WKWebview browser view controller in Swift"

  s.description       = <<-DESC
                      A simple view controller for navigating web pages using WKWebView. iOS 8.1+.
                      Supports Swift 4.0 and iOS 11 SDK.
                      DESC

  s.homepage          = "https://github.com/LaserSrl/LaserWebViewController"
  s.screenshots       = "https://cloud.githubusercontent.com/assets/3193877/7665617/29a8672a-fbc9-11e4-98cf-41fec0f6c403.gif"

  s.license           = { :type => "MIT", :file => "LICENSE" }

  s.author            = { "Patrick Laser" => "patrick.negretto@laser-group.com" }
  s.social_media_url  = "http://twitter.com/"

  s.platform          = :ios
  s.ios.deployment_target   = '11.0'
  s.swift_version           = '5.0'
  s.source            = { :git => "https://github.com/LaserSrl/LaserWebViewController.git", :tag => s.version }

  s.source_files      = "GDWebViewController/*"
end
