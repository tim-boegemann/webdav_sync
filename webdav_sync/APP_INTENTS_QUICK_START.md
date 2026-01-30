# App Intents - Quick Start

## 🚀 Sofort starten in 3 Schritten

### 1️⃣ App installieren
```bash
flutter run -d <device-id>
```

### 2️⃣ Shortcuts App öffnen
- Auf deinem iPhone: **Öffne die Shortcuts App**

### 3️⃣ Suche nach deiner App
- Tippe auf **"+"** (neue Shortcut)
- Tippe auf **"+"** um Action hinzuzufügen
- Suche nach: **"WebDAV"** oder **"Alle synchronisieren"**
- Der Block erscheint! 🎉

---

## 🎯 Was du jetzt siehst

In der Shortcuts App findest du diese **Custom Blocks**:

```
┌─────────────────────────────────┐
│ Alle synchronisieren            │
├─────────────────────────────────┤
│ Synchronisiert alle WebDAV-     │
│ Konfigurationen nacheinander.   │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ Konfiguration synchronisieren   │
├─────────────────────────────────┤
│ Konfiguration: [Parameter]      │
│ Synchronisiert eine bestimmte   │
│ WebDAV-Konfiguration.           │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ Sync-Status anzeigen            │
├─────────────────────────────────┤
│ Zeigt den aktuellen Status an.  │
└─────────────────────────────────┘
```

---

## 📱 Erste Shortcut erstellen

### Variante A: Einfach (Alle synchen)

1. **Shortcuts App öffnen**
2. Tippe **"+"** (neue Shortcut)
3. Tippe **"+"** (neue Action)
4. Suche: **"Alle synchronisieren"**
5. Block wird hinzugefügt ✓
6. Speichern & fertig! 🎉

**Das war's!** Die Shortcut ist ready!

### Variante B: Mit Parameter (Einzelne Config)

1. **Shortcuts App öffnen**
2. Tippe **"+"** (neue Shortcut)
3. Tippe **"+"** (neue Action)
4. Suche: **"Konfiguration synchronisieren"**
5. Im Parameter **"Konfiguration"** - deine Config wählen
6. Speichern & fertig! 🎉

---

## 🏠 Homescreen Button

Damit du einen **schnellen Button** hast:

1. Öffne deine erstellte Shortcut
2. Tippe **⋯** (drei Punkte)
3. Wähle **"Zum Bildschirm hinzufügen"**
4. Icon & Farbe wählen
5. **Fertig!** Jetzt auf Homescreen 🏡

---

## ⏰ Automatisch synchen (Automation)

### Jeden Tag um 08:00 Uhr

1. **Shortcuts App öffnen**
2. Gehe zu **"Automation"** (unten)
3. Tippe **"+"** (neue Automation)
4. Wähle **"Zeit"**
5. Stelle **08:00 Uhr** ein
6. Nächsten Tag: "Shortcut ausführen"
7. Wähle deine Shortcut
8. **Fertig!** Täglich automatisch 🤖

### Bei Wlan-Verbindung

1. **Automation erstellen**
2. Wähle **"Wlan"** als Trigger
3. Wähle dein Netzwerk
4. Aktion: "Shortcut ausführen"
5. **Fertig!** Auto-Sync beim Wlan-Connect 📶

---

## 🗣️ Mit Siri verwenden

Du kannst auch **Siri Sprachbefehle** nutzen:

```
"Siri, WebDAV synchronisieren"
→ Shortcut wird ausgeführt 🎤
```

Die Sprachbefehle sind in der App definiert!

---

## 📲 Verschiedene Szenarien

### Szenario 1: Morgens synchen
```
08:00 Uhr → Automation → Alle synchronisieren
↓
Alle Konfigurationen sind aktuell wenn du aufwachst
```

### Szenario 2: Nach Wlan-Verbindung
```
Verbinde mit Heim-Wlan
↓
Automation triggert
↓
Alle Dateien werden synchronisiert 📱
```

### Szenario 3: Homescreen Button
```
Drücke Button auf Homescreen
↓
App öffnet sich
↓
Sync startet sofort ⚡
```

### Szenario 4: Vor anderen Aktionen
```
1. Öffne Cloud-Datei-App
2. WebDAV synchronisieren
3. Datei anschauen
→ Daten sind immer aktuell
```

---

## ✅ Checkliste

- [ ] App installiert (`flutter run`)
- [ ] Shortcuts App öffnet
- [ ] Custom Block "Alle synchronisieren" gefunden
- [ ] Erste Shortcut erstellt
- [ ] Zum Homescreen hinzugefügt (optional)
- [ ] Mit Siri getestet (optional)
- [ ] Automation erstellt (optional)

---

## 🆘 Fehlersuche

### Blocks werden nicht angezeigt?

**Lösung:**
1. App neu starten: `flutter run`
2. iPhone neu starten (Power-Cycle)
3. Shortcuts App neu starten
4. In Suchfeld direkt "WebDAV" eingeben

### Block funktioniert nicht?

**Lösung:**
1. App hat Berechtigungen? Überprüfe Einstellungen
2. Netzwerk OK? Überprüfe Internetverbindung
3. Konfiguration gültig? Öffne die App und überprüfe

### Sync startet nicht?

**Lösung:**
1. Öffne die WebDAV Sync App
2. Überprüfe Status
3. Teste Verbindung in der App
4. Überprüfe Debug-Logs (Xcode Console)

---

## 📚 Mehr Infos

- **Ausführliche Anleitung:** [APP_INTENTS_GUIDE.md](APP_INTENTS_GUIDE.md)
- **Technische Details:** [APP_INTENTS_TECHNICAL.md](APP_INTENTS_TECHNICAL.md)
- **Datei-Hash-Synchronisierung:** [README.md](README.md)

---

## 🎉 Fertig!

Du hast die App Intents Integration erfolgreich eingerichtet! 

Genießen Sie die **native iOS Shortcuts Integration** 🚀

Viel Spaß beim Automatisieren! 😎
