# 🔐 Passwort-Sicherheit

## ⚠️ KRITISCHES UPDATE: Verschlüsselte Passwort-Speicherung

### Problem (VOR)
```❌ UNSICHER
SharedPreferences.setString('password', 'mein-passwort')  ← Klartext!
```
Passwörter wurden im Klartext in lokale Datenbanken gespeichert:
- **Android**: `shared_preferences` → SQLite (lesbar für andere Apps)
- **iOS**: `NSUserDefaults` → Klartext-Plist-Datei
- **Windows/Linux/macOS**: JSON-Datei (Klartext)

### Lösung (JETZT)
```✅ SICHER
CredentialsService.saveCredentials()  ← Verschlüsselt!
```

Passwörter werden jetzt verschlüsselt gespeichert mit plattformspezifischen Mechanismen:

| Plattform | Speicher | Verschlüsselung |
|-----------|----------|-----------------|
| **Android** | Keystore | RSA-ECB + AES-GCM (hardwaregestützt) |
| **iOS** | Keychain | iCloud-Keychain (Apple Standard) |
| **Windows** | DPAPI | OS-native Verschlüsselung |
| **Linux** | Verschlüsselte Datei | AES-256 |
| **macOS** | Keychain | Apple Standard |

---

## 🏗️ Architektur

### 1. CredentialsService
```dart
class CredentialsService {
  // Speichert Passwörter verschlüsselt
  Future<void> saveCredentials({
    required String configId,
    required String username,
    required String password,
  });
  
  // Lädt Passwörter entschlüsselt
  Future<({String? username, String? password})> getCredentials(String configId);
  
  // Löscht Passwörter sicher
  Future<void> deleteCredentials(String configId);
}
```

### 2. SyncConfig
```dart
class SyncConfig {
  // NICHT mehr hier:
  @Deprecated('Nutze CredentialsService')
  final String password;  // ← Wird beim Speichern NICHT serialisiert!
  
  // toMap() gibt Passwort NICHT zurück:
  Map<String, dynamic> toMap() {
    return {
      // ... alle Felder AUSSER password
    };
  }
}
```

### 3. ConfigService
```dart
class ConfigService {
  final CredentialsService _credentialsService;
  
  // Speichert Config UND Passwort:
  Future<void> saveConfig(SyncConfig config) async {
    // 1. Speichere Passwort in CredentialsService
    await _credentialsService.saveCredentials(...);
    
    // 2. Speichere Config (ohne Passwort) in SharedPreferences
    await prefs.setString(_configsKey, jsonEncode(...));
  }
  
  // Lädt Config UND Passwort:
  Future<SyncConfig?> loadConfig(String id) async {
    // 1. Lade Config aus SharedPreferences
    var config = configs.firstWhere(...);
    
    // 2. Lade Passwort aus CredentialsService
    final credentials = await _credentialsService.getCredentials(id);
    
    // 3. Kombiniere beide
    return SyncConfig(..., password: credentials.password);
  }
}
```

---

## 🔄 Datenfluss

### Beim Speichern:
```
Benutzer gibt Passwort ein
         ↓
ConfigScreen speichert SyncConfig
         ↓
ConfigService.saveConfig()
         ├─→ CredentialsService.saveCredentials()  [Verschlüsselt]
         └─→ SharedPreferences (SyncConfig ohne Passwort)
```

### Beim Laden:
```
App startet / Benutzer öffnet Config
         ↓
ConfigService.loadConfig(id)
         ├─→ SharedPreferences (SyncConfig laden)
         ├─→ CredentialsService.getCredentials()  [Entschlüsselt]
         └─→ SyncConfig mit Passwort im Memory
         
(Passwort wird NUR im RAM gehalten!)
```

### Beim Löschen:
```
Benutzer löscht Config
         ↓
ConfigService.deleteConfig(id)
         ├─→ CredentialsService.deleteCredentials()  [Sicher gelöscht]
         └─→ SharedPreferences.remove()
```

---

## 📋 Best Practices

### ✅ Damit arbeiten:
```dart
// Passwort ist im RAM der laufenden App
// 1. Vom UI eingegeben
// 2. In ConfigService gespeichert
// 3. Von WebdavSyncService geladen

final credentials = await configService.loadConfig(configId);
final password = credentials.password;  // ← Entschlüsselt im RAM
```

### ❌ NICHT machen:
```dart
// ❌ FALSCH: Passwort hardcoden
const password = 'mein-passwort';

// ❌ FALSCH: Passwort loggen
logger.i('Password: $password');

// ❌ FALSCH: Passwort in SharedPreferences speichern
await prefs.setString('password', password);

// ❌ FALSCH: Passwort über unsichere Kanäle senden
// (Verwende nur HTTPS mit zertifikatsverfizierung)
```

---

## 🧪 Testing & Verifizierung

### Android (Emulator)
```bash
flutter run -d emulator
# Passwörter in Keystore:
adb shell "sqlite3 /data/data/[app-package]/shared_prefs/..."
# Sollte Passwort NICHT zeigen ✅
```

### iOS (Simulator)
```bash
# Keychain ist geschützt und nicht lesbar ✅
```

### Verschlüsselung verifizieren:
```dart
// Test-Code:
final service = CredentialsService();

// Speichern
await service.saveCredentials(
  configId: 'test-123',
  username: 'testuser',
  password: 'secret123',
);

// Laden
final creds = await service.getCredentials('test-123');
print(creds.password);  // "secret123" ✅

// In SharedPreferences sollte Passwort NICHT stehen!
final prefs = await SharedPreferences.getInstance();
final keys = prefs.getKeys();
print(keys);  // Kein "password" zu sehen ✅
```

---

## 📊 Sicherheits-Verbesserung

| Aspekt | Vorher | Nachher |
|--------|--------|---------|
| **Passwort-Speicherung** | Klartext | Verschlüsselt |
| **Zugriffsschutz** | Nein (andere Apps lesbar) | Ja (nur diese App) |
| **OS-Integration** | SharedPreferences | Keystore/Keychain |
| **Hardware-Sicherheit** | Nein | Ja (Android Keystore) |
| **Automatisches Löschen** | Nein | Ja (mit Config-Löschung) |

---

## 🚀 Migration bestehender Daten

Falls die App bereits Daten mit alten Passwörtern hat:

```dart
// Migration-Code (einmalig beim Start):
Future<void> migrateOldPasswords() async {
  final configs = await configService.getAllConfigs();
  
  for (final config in configs) {
    // Alte Passwörter aus SharedPreferences
    if (config.password.isNotEmpty) {
      // Neu in CredentialsService speichern
      await credentialsService.saveCredentials(
        configId: config.id,
        username: config.username,
        password: config.password,
      );
      
      // Aus SharedPreferences entfernen (optional)
      // Das passiert automatisch beim nächsten Speichern
    }
  }
}
```

---

## 🔗 Abhängigkeiten

In `pubspec.yaml`:
```yaml
dependencies:
  flutter_secure_storage: ^9.0.0
  shared_preferences: ^2.0.0
```

### Android (AndroidManifest.xml)
```xml
<!-- Keine zusätzlichen Permissions nötig! -->
<!-- flutter_secure_storage nutzt EncryptedSharedPreferences -->
```

### iOS (Info.plist)
```xml
<!-- Keine zusätzlichen Einträge nötig -->
<!-- Keychain wird automatisch genutzt -->
```

---

## 📝 Änderungsprotokoll

### 2026-02-06
- ✅ `CredentialsService` implementiert (flutter_secure_storage)
- ✅ `SyncConfig.password` als @Deprecated markiert
- ✅ `ConfigService` mit sicherer Passwort-Verwaltung aktualisiert
- ✅ Dokumentation erstellt
