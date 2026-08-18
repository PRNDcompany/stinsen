Pod::Spec.new do |s|
    s.name         = 'Stinsen'
    s.version      = '2.0.11'
    s.summary      = 'Coordinator pattern for iOS, with UIKit owning navigation and SwiftUI first-class on top.'
    s.homepage     = 'https://github.com/rundfunk47/stinsen'
    s.license      = { :type => 'MIT License' }
    s.author      = { 'Narek Mailian' => 'narek.mailian@gmail.com' }
    s.source       = { :git => 'https://github.com/rundfunk47/stinsen.git', :tag => s.version }
    s.source_files = 'Sources/**/*.swift'
    s.frameworks   = 'SwiftUI', 'UIKit'
    s.ios.deployment_target  = '15.0'
    s.swift_version = '5.9'
end
