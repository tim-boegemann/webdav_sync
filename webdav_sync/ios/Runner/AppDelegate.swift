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
    
    // Initialisiere Method Channel für Shortcuts
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "com.webdav-sync/shortcuts",
                                      binaryMessenger: controller.binaryMessenger)
    
    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      result(nil)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
