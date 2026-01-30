import AppIntents
import Foundation
import UIKit

// MARK: - Intent: Sync All Configs
struct SyncAllConfigsIntent: AppIntent {
    static var title: LocalizedStringResource = "Alle synchronisieren"
    static var description = IntentDescription("Synchronisiert alle WebDAV-Konfigurationen nacheinander.")
    
    @Dependency
    var webdavSyncManager: WebdavSyncManager

    func perform() async throws -> some IntentResult {
        do {
            let result = await webdavSyncManager.syncAllConfigs()
            return .result(value: result)
        } catch {
            throw error
        }
    }
}

// MARK: - Intent: Sync Specific Config
struct SyncConfigIntent: AppIntent {
    static var title: LocalizedStringResource = "Konfiguration synchronisieren"
    static var description = IntentDescription("Synchronisiert eine bestimmte WebDAV-Konfiguration.")

    @Parameter(title: "Konfiguration")
    var configName: String
    
    @Dependency
    var webdavSyncManager: WebdavSyncManager

    func perform() async throws -> some IntentResult {
        do {
            let result = await webdavSyncManager.syncConfig(named: configName)
            return .result(value: result)
        } catch {
            throw error
        }
    }
}

// MARK: - Intent: Get Sync Status
struct GetSyncStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Sync-Status anzeigen"
    static var description = IntentDescription("Zeigt den aktuellen Synchronisationsstatus an.")
    
    @Dependency
    var webdavSyncManager: WebdavSyncManager

    func perform() async throws -> some IntentResult {
        let status = await webdavSyncManager.getCurrentStatus()
        return .result(value: status)
    }
}

// MARK: - App Shortcuts Provider
struct WebdavSyncShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        [
            AppShortcut(
                intent: SyncAllConfigsIntent(),
                phrases: ["Alle synchronisieren", "WebDAV synchronisieren"]
            ),
            AppShortcut(
                intent: SyncConfigIntent(),
                phrases: ["\\(.configName) synchronisieren"]
            ),
            AppShortcut(
                intent: GetSyncStatusIntent(),
                phrases: ["WebDAV Status", "Sync-Status"]
            )
        ]
    }
}

// MARK: - WebDAV Sync Manager (iOS Bridge)
actor WebdavSyncManager {
    static let shared = WebdavSyncManager()
    
    private var isRunning = false
    
    func syncAllConfigs() async -> String {
        guard !isRunning else {
            return "Sync läuft bereits."
        }
        
        isRunning = true
        defer { isRunning = false }
        
        // Trigger Dart via Method Channel
        await callDartMethod(method: "handleShortcutCommand", arguments: [
            "command": "syncall",
            "params": [:]
        ])
        
        return "Alle Konfigurationen werden synchronisiert..."
    }
    
    func syncConfig(named: String) async -> String {
        guard !isRunning else {
            return "Sync läuft bereits."
        }
        
        isRunning = true
        defer { isRunning = false }
        
        // Trigger Dart via Method Channel
        await callDartMethod(method: "handleShortcutCommand", arguments: [
            "command": "syncconfig",
            "params": ["configName": named]
        ])
        
        return "Synchronisiere '\(named)'..."
    }
    
    func getCurrentStatus() async -> String {
        // Trigger Dart via Method Channel
        await callDartMethod(method: "handleShortcutCommand", arguments: [
            "command": "getstatus",
            "params": [:]
        ])
        
        return "Status wird abgerufen..."
    }
    
    private func callDartMethod(method: String, arguments: [String: Any]) async {
        DispatchQueue.main.async {
            guard let controller = UIApplication.shared.delegate?.window??.rootViewController as? FlutterViewController else {
                print("Fehler: FlutterViewController nicht gefunden")
                return
            }
            
            let channel = FlutterMethodChannel(
                name: "com.webdav-sync/shortcuts",
                binaryMessenger: controller.binaryMessenger
            )
            
            channel.invokeMethod(method, arguments: arguments) { result in
                print("Dart Response: \(result ?? "nil")")
            }
        }
    }
}
