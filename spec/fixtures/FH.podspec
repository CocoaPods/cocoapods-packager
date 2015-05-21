Pod::Spec.new do |s|
  s.name         = 'FH'
  s.version      = '2.2.8'
  s.summary      = 'FeedHenry iOS Software Development Kit'
  s.homepage     = 'https://www.feedhenry.com'
  s.social_media_url = 'https://twitter.com/feedhenry'
  s.license      = 'FeedHenry'
  s.author       = 'Red Hat, Inc.'
  s.source       = { :git => 'https://github.com/cvasilak/fh-ios-sdk.git', :branch => 'module_map' }
  s.platform     = :ios, 7.0
  s.source_files = 'fh-ios-sdk/**/*.{h,m}'
  s.public_header_files =  'fh-ios-sdk/FeedHenry.h', 'fh-ios-sdk/FH.h', 'fh-ios-sdk/FHAct.h', 'fh-ios-sdk/FHActRequest.h', 'fh-ios-sdk/FHAuthRequest.h', 'fh-ios-sdk/FHCloudProps.h', 'fh-ios-sdk/FHCloudRequest.h', 'fh-ios-sdk/FHConfig.h', 'fh-ios-sdk/FHResponse.h', 'fh-ios-sdk/FHResponseDelegate.h', 'fh-ios-sdk/Sync/FHSyncClient.h', 'fh-ios-sdk/Sync/FHSyncConfig.h', 'fh-ios-sdk/Sync/FHSyncNotificationMessage.h', 'fh-ios-sdk/Sync/FHSyncDelegate.h', 'fh-ios-sdk/Categories/JSON/FHJSON.h', 'fh-ios-sdk/FHDataManager.h'
  s.module_map = 'fh-ios-sdk/module.modulemap'
  s.requires_arc = true
  s.libraries = 'xml2', 'z'
  s.dependency 'ASIHTTPRequest/Core', '1.8.2'
  s.dependency 'Reachability', '3.2'
end
