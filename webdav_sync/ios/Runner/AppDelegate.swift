import Flutter
import UIKit
import AppIntents

// MARK: - Intent: Sync All Configs
@available(iOS 16.0, *)
struct SyncAllConfigsIntent: AppIntent {
    static var title: LocalizedStringResource = "Alle synchronisieren"
    static var description = IntentDescription("Synchronisiert alle WebDAV-Konfigurationen.")
    
    // 🚀 Öffne die App NUR wenn sie komplett geschlossen ist
    // Wenn sie im Hintergrund läuft, halte sie im Hintergrund
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        print("🚀 SyncAllConfigsIntent.perform() aufgerufen")
        
        do {
            WebdavSyncManager.shared.syncAllConfigs()
            // Gib einfach ein leeres Ergebnis zurück ohne Wert
            return .result()
        } catch {
            print("❌ Fehler in SyncAllConfigsIntent: \(error)")
            throw error
        }
    }
}

// MARK: - Intent: Open App
@available(iOS 16.0, *)
struct OpenAppIntent: AppIntent {
    static var title: LocalizedStringResource = "App öffnen"
    static var description = IntentDescription("Öffnet die WebDAV Sync App.")
    
    // 🚀 Öffne IMMER die App (das ist die Absicht dieses Shortcuts)
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        print("🚀 OpenAppIntent.perform() aufgerufen - App wird geöffnet")
        // Einfach nur die App öffnen, nichts weiter
        return .result()
    }
}

// MARK: - App Shortcuts Provider
@available(iOS 16.0, *)
struct WebdavSyncShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SyncAllConfigsIntent(),
            phrases: ["Alle synchronisieren in \(.applicationName)", "WebDAV synchronisieren in \(.applicationName)"]
        )
        
        AppShortcut(
            intent: OpenAppIntent(),
            phrases: ["Öffne \(.applicationName)", "\(.applicationName) öffnen"]
        )
    }
}

// MARK: - WebDAV Sync Manager
class WebdavSyncManager {
    static let shared = WebdavSyncManager()
    
    func syncAllConfigs() {
        print("📲 syncAllConfigs aufgerufen")
        callDartMethod(method: "handleShortcutCommand", arguments: [
            "command": "syncall",
            "params": [:]
        ])
    }
    
    private func callDartMethod(method: String, arguments: [String: Any]) {
        // Nutze DispatchQueue.main um sicher auf dem Main Thread zu sein
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("❌ WebdavSyncManager wurde deallocated")
                return
            }
            
            // Finde den FlutterViewController
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let controller = window.rootViewController as? FlutterViewController else {
                print("❌ ERROR: FlutterViewController nicht verfügbar")
                return
            }
            
            let channel = FlutterMethodChannel(
                name: "com.webdav-sync/shortcuts",
                binaryMessenger: controller.binaryMessenger
            )
            
            print("📤 Sende zu Dart: \(method)")
            
            channel.invokeMethod(method, arguments: arguments) { result in
                if let result = result {
                    print("✅ Dart antwortet: \(result)")
                } else {
                    print("⚠️ Dart antwortet mit nil")
                }
            }
        }
    }
}

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
