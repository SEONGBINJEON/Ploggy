import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Info.plist의 GMSApiKey에 iOS용 Google Maps API 키를 넣어야 지도가 표시됩니다.
    // 키를 아예 등록하지 않으면 지도를 만들 때 앱이 종료되므로, 임시 값이라도 항상 등록합니다.
    // (임시 값이면 지도만 빈 화면으로 나옵니다)
    let mapsApiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? ""
    GMSServices.provideAPIKey(mapsApiKey.isEmpty ? "YOUR_IOS_MAPS_API_KEY" : mapsApiKey)
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
