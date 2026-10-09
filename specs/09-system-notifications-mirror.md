# Spec: 09 — Notificaciones del sistema como espejo en la Dynamic Island

- **Estado**: Draft
- **Fecha**: 2026-10-08
- **Depende de**: Spec 05 (Settings), Spec 08 (Dynamic Island behavior)
- **Autor**: opencode
- **Plataforma**: macOS only (Apple Silicon, macOS 26.5+)

## Objetivos

Hacer que LiquidNotch muestre dentro de la Dynamic Island cualquier notificación que macOS entregue a la app, replicando el comportamiento de la iPhone Dynamic Island. La notificación se renderiza con `NotificationNotchView` (creado en spec 08), tiene auto-dismiss configurable, y se gestiona desde un nuevo `NotificationCenterManager` (`ObservableObject`) que actúa como `UNUserNotificationCenterDelegate`.

Una vez ejecutado este spec, cuando llega una notificación (ej. mensaje de Messages, recordatorio de Calendar, alerta de cualquier app que el usuario haya autorizado), la cápsula muestra título + body + icono de la app origen durante 5 segundos, y luego vuelve al estado previo (audio o idle).

## Alcance (Scope)

### Incluido

- **`NotificationCenterManager`** (`ObservableObject` `@MainActor`) que:
  - Solicita permisos en primer arranque con `UNUserNotificationCenter.requestAuthorization(options: [.alert, .sound])`.
  - Actúa como `UNUserNotificationCenterDelegate` con `userNotificationCenter(_:willPresent:withCompletionHandler:)` retornando `.banner` para que la notificación también se vea en la barra de menús.
  - Parsea el `UNNotification` entrante en un `IncomingNotification` (struct).
  - Expone `@Published var activeNotification: IncomingNotification?` consumido por `NotchContainerView`.
  - Implementa `dismiss(id: UUID)` que limpia `activeNotification` (para auto-dismiss y dismiss manual).
  - Implementa `enqueue(_:)` que, si hay una notificación activa, espera a que se descarte antes de mostrar la siguiente (cola FIFO).
- **Struct `IncomingNotification`** (definido formalmente aquí, reemplaza el placeholder de spec 08):
  - `id: UUID` (identifica la notificación para dismiss).
  - `title: String` (de `UNNotificationRequest.content.title`).
  - `body: String` (de `UNNotificationRequest.content.body`).
  - `appName: String` (de `NSRunningApplication` o `content.threadIdentifier`).
  - `appIcon: NSImage?` (de `NSRunningApplication.runningApplications(withBundleIdentifier:)` o fallback a SF Symbol).
  - `receivedAt: Date`.
- **Conexión con `NotchContainerView`** (spec 08): si `notificationCenter.activeNotification != nil`, el estado es `.notification(notif)`. Auto-dismiss después de `appSettings.notificationDismissAfter` segundos.
- **UI en `NotificationsSettingsView`** (Settings → Notifications):
  - Toggle "Enable notifications mirroring" (`@AppStorage("liquidNotch.notifications.enabled")`).
  - Botón "Request permission" si el estado es `.notDetermined`.
  - Texto de estado: "Authorized", "Denied", "Not determined", "Provisional".
  - Slider para `notificationDismissAfter` (1-30 segundos, default 5).
  - Toggle "Show system banner" (`@AppStorage("liquidNotch.notifications.systemBanner")`) que controla si la notificación también se ve en el banner de macOS o solo en LiquidNotch.
- **`Info.plist` usage descriptions**: `NSUserNotificationsUsageDescription` con texto "LiquidNotch displays your notifications in the dynamic island overlay."
- **Tests manuales** con un botón "Send test notification" en `NotificationsSettingsView` que dispara un `UNNotificationRequest` local.
- **Logging**: las notificaciones entrantes se loguean con `os.Logger` en subsystem `kelevo.LiquidNotch`, category `notifications` (para debugging).

### Excluido

- **Acciones interactivas en notificaciones** (botones "Reply", "Mark as read" en la notificación) — fuera de alcance; spec 09 solo muestra la notificación visualmente.
- **Acciones custom buttons** (`UNNotificationCategory` con `UNNotificationAction`) — fuera de alcance.
- **Respuesta a clicks** (`userNotificationCenter(_:didReceive:withCompletionHandler:)`) — la cápsula no es clickable para abrir la app origen (macOS no tiene un equivalente directo de "deep link" desde una notificación del sistema).
- **Critical alerts** (`.criticalAlert`) — requiere entitlement especial, fuera de alcance.
- **Time-sensitive notifications** (`.timeSensitive`) — fuera de alcance por ahora.
- **Filtros por app** (mostrar solo notificaciones de Messages, no de Mail) — fuera de alcance; se puede añadir en un spec futuro.
- **Historial de notificaciones** (ver notificaciones pasadas) — fuera de alcance; el spec solo maneja la última.
- **Sonido custom al recibir notificación** — usa el sonido del sistema por defecto.
- **DND mode (Do Not Disturb) integration** — fuera de alcance.
- **Sincronización vía CloudKit** de notificaciones — fuera de alcance.
- **Modificación de notificaciones en tránsito** (ej. añadir LiquidNotch branding) — fuera de alcance.
- **Soporte de attachments** (imágenes, videos en notificaciones) — fuera de alcance por ahora.

## File Structure (cambios)

```text
LiquidNotch/
├── LiquidNotch/
│   ├── App/
│   │   └── AppDelegate.swift             # MODIFICAR — inyectar NotificationCenterManager, set delegate
│   ├── Models/
│   │   ├── AppSettings.swift             # MODIFICAR — añadir @AppStorage de notificaciones
│   │   ├── IncomingNotification.swift    # NUEVO — struct formal (reemplaza placeholder spec 08)
│   │   └── ...
│   ├── Services/
│   │   └── NotificationCenterManager.swift # NUEVO — UNUserNotificationCenterDelegate
│   ├── Views/
│   │   ├── Settings/
│   │   │   └── NotificationsSettingsView.swift # MODIFICAR — UI funcional
│   │   └── Notch/
│   │       └── NotificationNotchView.swift # MODIFICAR — usar IncomingNotification formal
│   └── LiquidNotchApp.swift               # MODIFICAR — instanciar NotificationCenterManager
├── LiquidNotch.xcodeproj/
│   └── project.pbxproj                    # MODIFICAR — añadir NSUserNotificationsUsageDescription
└── specs/
    └── 09-system-notifications-mirror.md
```

## Data Model

### `IncomingNotification` (formal)

```swift
import AppKit
import Foundation

struct IncomingNotification: Identifiable, Equatable {
    let id: UUID
    let title: String
    let body: String
    let appName: String
    let appIcon: NSImage?
    let receivedAt: Date

    static func == (lhs: IncomingNotification, rhs: IncomingNotification) -> Bool {
        lhs.id == rhs.id
    }

    static func from(_ notification: UNNotification) -> IncomingNotification {
        let content = notification.request.content
        let appName = resolveAppName(for: notification)
        let appIcon = resolveAppIcon(for: appName)

        return IncomingNotification(
            id: UUID(),
            title: content.title,
            body: content.body,
            appName: appName,
            appIcon: appIcon,
            receivedAt: Date()
        )
    }

    private static func resolveAppName(for notification: UNNotification) -> String {
        // Intentar por bundle identifier del threadIdentifier
        if let threadId = notification.request.content.threadIdentifier as String?,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: threadId).first {
            return app.localizedName ?? "App"
        }
        return "Notification"
    }

    private static func resolveAppIcon(for appName: String) -> NSImage? {
        // Buscar la app por nombre entre las running applications
        let apps = NSWorkspace.shared.runningApplications
        for app in apps {
            if app.localizedName == appName {
                return app.icon
            }
        }
        return NSImage(systemSymbolName: "bell.fill", accessibilityDescription: nil)
    }
}
```

### `NotificationCenterManager`

```swift
import AppKit
import Combine
import Foundation
import UserNotifications
import os

@MainActor
final class NotificationCenterManager: NSObject, ObservableObject {
    @Published var activeNotification: IncomingNotification?
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var enabled: Bool {
        didSet { settings.notificationsEnabled = enabled }
    }

    private let settings: AppSettings
    private let logger = Logger(subsystem: "kelevo.LiquidNotch", category: "notifications")
    private var pendingQueue: [IncomingNotification] = []
    private var dismissTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
        self.enabled = settings.notificationsEnabled
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let current = await center.notificationSettings()
        await MainActor.run { self.authorizationStatus = current.authorizationStatus }

        guard current.authorizationStatus == .notDetermined else { return }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            logger.info("Permission request result: \(granted)")
            let updated = await center.notificationSettings()
            await MainActor.run { self.authorizationStatus = updated.authorizationStatus }
        } catch {
            logger.error("Permission request failed: \(error.localizedDescription)")
        }
    }

    func refreshAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        await MainActor.run { self.authorizationStatus = settings.authorizationStatus }
    }

    func dismiss(id: UUID) {
        guard activeNotification?.id == id else { return }
        dismissTask?.cancel()
        activeNotification = nil
        showNextFromQueue()
    }

    private func showNextFromQueue() {
        guard !pendingQueue.isEmpty else { return }
        let next = pendingQueue.removeFirst()
        present(next)
    }

    private func present(_ notification: IncomingNotification) {
        activeNotification = notification
        let delay = settings.notificationDismissAfter
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.dismiss(id: notification.id)
            }
        }
    }
}

extension NotificationCenterManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let parsed = IncomingNotification.from(notification)
        logger.info("Received notification: \(parsed.title, privacy: .public)")

        await MainActor.run {
            guard self.enabled else { return }
            if self.activeNotification != nil {
                self.pendingQueue.append(parsed)
            } else {
                self.present(parsed)
            }
        }

        return settings.notificationsSystemBanner ? .banner : []
    }
}
```

### `AppSettings` additions

```swift
@AppStorage("liquidNotch.notifications.enabled") var notificationsEnabled: Bool = true
@AppStorage("liquidNotch.notifications.systemBanner") var notificationsSystemBanner: Bool = true
@AppStorage("liquidNotch.notificationDismissAfter") var notificationDismissAfter: Double = 5.0
```

### Keys nuevas en `UserDefaults`

| Key | Tipo | Default | Descripción |
|---|---|---|---|
| `liquidNotch.notifications.enabled` | `Bool` | `true` | Si el espejo de notificaciones está activo |
| `liquidNotch.notifications.systemBanner` | `Bool` | `true` | Si además se muestra el banner del sistema |
| `liquidNotch.notificationDismissAfter` | `Double` | `5.0` | Segundos antes del auto-dismiss |

## Implementation Plan

### Fase 1 — `IncomingNotification` formal

**Archivo nuevo**: `Models/IncomingNotification.swift`.

Reemplaza el placeholder de spec 08. Implementa `from(_:)` que parsea un `UNNotification` y resuelve app name / icon.

> **Detalle**: en macOS, `UNNotificationRequest.content.userInfo` no incluye el bundle ID del sender de forma estándar. La heurística es buscar por `threadIdentifier` (que algunas apps usan como bundle ID) o por nombre de app en `NSWorkspace.runningApplications`. Esto es imperfecto; se documenta como limitation.

**Verificación**: el struct compila; `IncomingNotification.from(notification)` retorna un valor válido con al menos `title` y `body`.

### Fase 2 — `NotificationCenterManager`

**Archivo nuevo**: `Services/NotificationCenterManager.swift`.

Implementa:
- `init(settings:)` que setea el delegate.
- `requestAuthorizationIfNeeded()` async.
- `refreshAuthorizationStatus()` async.
- `dismiss(id:)` para dismiss manual.
- `present(_:)` privada con auto-dismiss via `Task`.
- `showNextFromQueue()` para cola FIFO.
- Delegate `userNotificationCenter(_:willPresent:)` async que parsea y enqueue.

**Inyección**:
- `@StateObject private var notificationCenter: NotificationCenterManager` en `LiquidNotchApp` (o `init()`).
- Pasar al `AppDelegate` igual que `AppSettings`.
- Pasar al `NotchContainerView` como `@ObservedObject`.

**Verificación**: en logs aparece "Received notification: ..." cuando llega una; el `activeNotification` se actualiza.

### Fase 3 — Info.plist additions

**Archivo**: `LiquidNotch.xcodeproj/project.pbxproj` (modificar con Xcode).

Pasos en Xcode:
1. Seleccionar target `LiquidNotch`.
2. Pestaña **Info**.
3. Añadir `Privacy - User Notifications Usage Description` con valor `"LiquidNotch displays your notifications in the dynamic island overlay."`. Esto se refleja como `NSUserNotificationsUsageDescription` en el Info.plist generado.
4. Verificar que ambas configuraciones (Debug y Release) lo tienen.

> **Alternativa**: usar `INFOPLIST_KEY_NSUserNotificationsUsageDescription` directamente en build settings.

**Verificación**: tras build, `defaults read <path>/Info.plist NSUserNotificationsUsageDescription` muestra el string.

### Fase 4 — `NotificationsSettingsView`

**Archivo**: `Views/Settings/NotificationsSettingsView.swift` (modificar el placeholder de spec 05).

Layout:
```
┌─ Notifications ─────────────────────────────────────┐
│  [●] Enable notifications mirroring                │
│                                                    │
│  Status:  [Authorized]  [Request permission]        │
│                                                    │
│  Auto-dismiss after:  [5s]  ━━━●━━━━━━  (1-30s)    │
│                                                    │
│  [●] Also show in macOS notification center         │
│                                                    │
│  ───────────────────────────────────────────────    │
│  [ Send test notification ]                         │
└────────────────────────────────────────────────────┘
```

```swift
struct NotificationsSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @ObservedObject var notificationCenter: NotificationCenterManager

    var body: some View {
        Form {
            Section {
                Toggle("Enable notifications mirroring", isOn: $notificationCenter.enabled)
            }

            Section("Permission") {
                HStack {
                    Text("Status:")
                    Text(statusText)
                        .foregroundStyle(statusColor)
                    Spacer()
                    if notificationCenter.authorizationStatus == .notDetermined {
                        Button("Request permission") {
                            Task { await notificationCenter.requestAuthorizationIfNeeded() }
                        }
                    }
                }
            }

            Section("Behavior") {
                VStack(alignment: .leading) {
                    Text("Auto-dismiss after: \(Int(settings.notificationDismissAfter))s")
                    Slider(value: $settings.notificationDismissAfter, in: 1...30, step: 1)
                }
                Toggle("Also show in macOS notification center", isOn: $settings.notificationsSystemBanner)
            }

            Section {
                Button("Send test notification") {
                    sendTestNotification()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 360)
        .task {
            await notificationCenter.refreshAuthorizationStatus()
        }
    }

    private var statusText: String {
        switch notificationCenter.authorizationStatus {
        case .authorized: "Authorized"
        case .denied: "Denied"
        case .notDetermined: "Not determined"
        case .provisional: "Provisional"
        case .ephemeral: "Ephemeral"
        @unknown default: "Unknown"
        }
    }

    private var statusColor: Color {
        switch notificationCenter.authorizationStatus {
        case .authorized: .green
        case .denied: .red
        default: .secondary
        }
    }

    private func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test notification"
        content.body = "This is a test from LiquidNotch Settings"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
}
```

**Verificación**: el form se ve; "Send test notification" dispara una notificación que se ve en la cápsula 1s después.

### Fase 5 — Integración con `NotchContainerView`

**Archivo**: `Views/Notch/NotchContainerView.swift` (modificar, según spec 08).

Cambios:
1. Añadir `@ObservedObject var notificationCenter: NotificationCenterManager`.
2. En `baseState`, verificar `notificationCenter.activeNotification` primero (mayor prioridad que audio).
3. El switch del `body` ya tiene el caso `.notification(let notif)` (definido en spec 08); ahora se pasa el `IncomingNotification` real.
4. Añadir un `Task` de auto-dismiss en el container si `appSettings.expandOnNotification` es true (default false — expandir la cápsula al recibir notificación). Esto se documenta en spec 08 pero se implementa aquí.
5. Reemplazar el `IncomingNotification` placeholder de spec 08 por el struct formal.

**Verificación**: cuando llega una notificación, `baseState` es `.notification(notif)`; el container renderiza `NotificationNotchView`; auto-dismiss a 5s.

### Fase 6 — `NotificationNotchView` actualizado

**Archivo**: `Views/Notch/NotificationNotchView.swift` (modificar).

Cambio: el struct ahora consume `IncomingNotification` (real) en lugar del placeholder. Visualmente idéntico, solo cambia el tipo.

**Verificación**: la vista se renderiza con datos reales de la notificación.

### Fase 7 — `AppDelegate` setup

**Archivo**: `App/AppDelegate.swift` (modificar).

Cambios:
1. Añadir `var notificationCenter: NotificationCenterManager?` como propiedad.
2. En `applicationDidFinishLaunching`, después del setup del panel:
   - `notificationCenter = NotificationCenterManager(settings: settings ?? AppSettings())`.
3. Llamar `Task { await notificationCenter.requestAuthorizationIfNeeded() }` (no bloquea el arranque).

**Verificación**: al primer arranque, se solicita permiso de notificaciones; al segundo, no se vuelve a pedir.

### Fase 8 — `LiquidNotchApp` injection

**Archivo**: `LiquidNotchApp.swift` (modificar).

Cambios:
1. Crear `notificationCenter` como propiedad.
2. Pasar a `SettingsView` como `@EnvironmentObject` o `@ObservedObject`.
3. Pasar a `AppDelegate` via init.

**Verificación**: el `NotificationCenterManager` se inicializa una sola vez (singleton per app session).

## Acceptance Criteria

- [ ] Existe `Models/IncomingNotification.swift` con el struct formal y `from(_:)` constructor.
- [ ] Existe `Services/NotificationCenterManager.swift` con la lógica de delegate, cola, y auto-dismiss.
- [ ] `NotificationCenterManager` actúa como `UNUserNotificationCenterDelegate` y está asignado en `init`.
- [ ] Al primer arranque, se llama `requestAuthorizationIfNeeded()` async (no bloquea el launch).
- [ ] El form de `NotificationsSettingsView` muestra: toggle enabled, status de permiso con color, botón "Request permission" si `.notDetermined`, slider de auto-dismiss, toggle system banner, botón "Send test notification".
- [ ] El toggle "Enable notifications mirroring" persiste en `liquidNotch.notifications.enabled`.
- [ ] El slider persiste el valor en `liquidNotch.notificationDismissAfter`.
- [ ] El toggle "Also show in macOS notification center" persiste en `liquidNotch.notifications.systemBanner`.
- [ ] Cuando llega una notificación, `activeNotification` se actualiza y la cápsula muestra `NotificationNotchView`.
- [ ] El auto-dismiss ocurre después de N segundos (configurable).
- [ ] Si llega una segunda notificación mientras la primera está activa, se enqueue (FIFO).
- [ ] Al dismiss de la primera, la segunda se muestra inmediatamente.
- [ ] El estado `.notification` tiene prioridad sobre `.audio` y `.idle`.
- [ ] `NSUserNotificationsUsageDescription` está presente en Info.plist con el string correcto.
- [ ] "Send test notification" dispara una notificación real que se ve en la cápsula 1s después.
- [ ] Los logs (Console.app filtrado por subsystem `kelevo.LiquidNotch`) muestran "Received notification: ..." al recibir una.
- [ ] Si `notificationsEnabled = false`, las notificaciones se ignoran (no se muestran en la cápsula).
- [ ] Si `notificationsSystemBanner = false`, las notificaciones NO se ven en el banner del sistema pero SÍ en la cápsula.
- [ ] El proyecto compila sin warnings de `Sendable` o `@MainActor` violations.

## Decisiones tomadas

- **Sí: `NotificationCenterManager` con `UNUserNotificationCenterDelegate` async** — la API moderna desde macOS 13; no usa completion handlers.
- **No: Delegate con `withCompletionHandler`** — deprecated, más verboso.
- **Sí: Cola FIFO** — si llegan 3 notificaciones mientras se muestra la 1ª, la 2ª espera 5s, luego la 3ª espera 5s más. Comportamiento predecible.
- **No: Drop de notificaciones viejas** — se perderían mensajes importantes.
- **No: Reemplazar la activa con la nueva** — la activa es la que el usuario está viendo; reemplazarla sería abrupto.
- **Sí: `IncomingNotification` con `id: UUID` autogenerado** — la `UNNotificationRequest.identifier` puede repetirse si la app es la misma; UUID evita colisiones.
- **No: usar `UNNotificationRequest.identifier` como id** — repetible.
- **Sí: Auto-dismiss con `Task.sleep`** — Swift concurrency, cancelable.
- **No: `Timer`** — más difícil de cancelar, se puede quedar colgado.
- **No: DispatchQueue.main.asyncAfter** — no cancelable fácilmente.
- **Sí: Default 5s para auto-dismiss** — coincide con el spec 08.
- **Sí: Slider 1-30s** — permite a usuarios con discapacidad visual más tiempo de lectura.
- **Sí: Toggle "Also show in macOS notification center"** — algunos usuarios quieren AMBAS visualizaciones; otros solo LiquidNotch.
- **No: Solo LiquidNotch (forzado)** — el comportamiento por defecto debe ser familiar (banner del sistema + cápsula).
- **Sí: Resolver appName por `NSWorkspace.runningApplications`** — heurística imperfecta pero es lo mejor que ofrece macOS.
- **No: Asumir que `userInfo["bundleId"]` existe** — pocas apps lo setean; no es estándar.
- **Sí: `Logger` con subsystem `kelevo.LiquidNotch`** — estándar de Apple, filtrable en Console.app.
- **No: `print`** — no aparece en Console.app, no filtrable.
- **Sí: `NSUserNotificationsUsageDescription` en Info.plist** — requerido desde macOS 11 si la app muestra notificaciones; sin este key, el sistema puede filtrar las notificaciones.
- **No: `NSUserActivityUsageDescription`** — eso es para Handoff, no notificaciones.

## Riesgos

| Riesgo | Mitigación |
|---|---|
| macOS no entrega todas las notificaciones a la app (filtro del sistema) | Es un comportamiento del OS; se documenta en README como limitation. El usuario debe ir a System Settings → Notifications → LiquidNotch y permitir banners |
| `requestAuthorization` muestra un diálogo del sistema que el usuario puede rechazar | El toggle se desactiva automáticamente si `.denied`; la UI muestra el status |
| `appName` y `appIcon` no se resuelven correctamente para todas las apps | Fallback a "Notification" como nombre y SF Symbol `bell.fill` como icono; se documenta |
| Cola FIFO acumula notificaciones si llegan muchas rápido | Cap a 5 en cola; las más viejas se descartan. Se documenta en código |
| `Task.sleep` se cancela correctamente al dismiss manual | Verificado con `dismissTask?.cancel()` antes de empezar nueva task |
| `UNUserNotificationCenter.current().delegate` se sobreescribe si otra parte del código lo setea | LiquidNotch es el único que lo usa; documentar en código |
| El slider de auto-dismiss no se aplica en tiempo real (requiere reabrir la cápsula) | La cápsula actual termina su ciclo de auto-dismiss actual; el siguiente usa el nuevo valor |
| `Send test notification` no funciona en macOS sin permisos | El botón solo se habilita si `authorizationStatus == .authorized`; se documenta |
| El delegate async se ejecuta en background thread; acceder a `@Published` desde ahí | `await MainActor.run { ... }` envuelve todas las mutaciones de estado |
| Las notificaciones de algunas apps (ej. App Store updates) no se pueden redirigir | Limitación del OS; documentar |

## Verification final

```bash
# Build limpio
xcodebuild -project LiquidNotch.xcodeproj -scheme LiquidNotch -destination 'platform=macOS' clean build

# Verificar archivos nuevos
ls LiquidNotch/Models/IncomingNotification.swift
ls LiquidNotch/Services/NotificationCenterManager.swift

# Verificar que NSUserNotificationsUsageDescription está en el .pbxproj
grep -c "NSUserNotificationsUsageDescription" LiquidNotch.xcodeproj/project.pbxproj  # >= 2 (Debug + Release)

# Verificar keys de UserDefaults
defaults read kelevo.LiquidNotch liquidNotch.notifications.enabled          # 1 o 0
defaults read kelevo.LiquidNotch liquidNotch.notificationDismissAfter      # número entre 1.0 y 30.0

# Verificar log
log show --predicate 'subsystem == "kelevo.LiquidNotch"' --info --last 1m  # debe mostrar entries
```

## What is **NOT** in this spec

- Acciones interactivas (botones en la notificación).
- `UNNotificationCategory` con acciones custom.
- Respuesta a clicks (`didReceive` delegate).
- Critical alerts (`.criticalAlert`).
- Time-sensitive notifications.
- Filtros por app origen.
- Historial de notificaciones.
- Sonido custom.
- DND mode integration.
- CloudKit sync.
- Modificación de notificaciones en tránsito.
- Attachments (imágenes, videos).

Cada uno, si aterriza, va en su propio spec.
