import Flutter
import UIKit
import AppIntents

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Initialisiere Method Channel für Shortcuts und Background Sync
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "com.webdav-sync/shortcuts",
                                      binaryMessenger: controller.binaryMessenger)
    
    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      result(nil)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - Background Fetch
  override func application(
    _ application: UIApplication,
    performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      completionHandler(.failed)
      return
    }
    
    let channel = FlutterMethodChannel(
      name: "com.webdav-sync/shortcuts",
      binaryMessenger: controller.binaryMessenger
    )
    
    // Timeout nach 25 Sekunden (Background Fetch hat nur ~30 Sekunden)
    let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 25.0, repeats: false) { _ in
      completionHandler(.newData)
    }
    
    channel.invokeMethod("handleBackgroundFetch", arguments: nil) { result in
      timeoutTimer.invalidate()
      
      if let result = result as? [String: Any],
         let success = result["success"] as? Bool,
         success {
        completionHandler(.newData)
      } else {
        completionHandler(.noData)
      }
    }
  }
}
