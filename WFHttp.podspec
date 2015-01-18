Pod::Spec.new do |s|
  s.name = 'WFHttp'
  s.version = '1.0.0'
  s.summary = 'Basic http class for iOS'
  s.homepage = 'https://github.com/williamFalcon/WFHttp'
  s.license = 'MIT'
  s.author = { 'williamFalcon' => 'will@hacstudios.com' }
  s.social_media_url = 'https://twitter.com/_willfalcon'
  s.source = { :git => 'https://github.com/williamFalcon/WFHttp.git', :tag => "v#{s.version}" }
  s.source_files = 'WFHttp/**/*.{h,m}'
  s.public_header_files = 'WFHttp/Public/**/*.{h,m}'
  s.requires_arc = true
  s.dependency 'Reachability'
  s.platform = :ios, '7.0'
end
