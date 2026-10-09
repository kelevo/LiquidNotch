# Spec: 05 — Settings Panel y eliminación del MenuBarExtra

- **Estado**: Draft
- **Fecha**: 2026-10-08
- **Depende de**: Spec 04 (open source prep)
- **Autor**: opencode
- **Plataforma**: macOS only (Apple Silicon)

## Objetivos

Eliminar el `MenuBarExtra` que muestra el icono de LiquidNotch en la barra de menús del sistema y reemplazarlo por un panel de Settings accesible mediante tres puntos de entrada estándar de macOS: atajo `Cmd+,`, click derecho sobre la cápsula, y un botón de engranaje en la vista expandida.

Una vez ejecutado este spec, LiquidNotch se comporta como una app "accessory" pura: sin icono en la barra de menús, sin icono en el Dock, pero con un panel de preferencias discoverable y consistente con las convenciones de macOS.

## Alcance (Scope)

### Incluido

- Eliminar el `MenuBarExtra` de `LiquidNotchApp.swift`.
- Crear `Settings` scene de SwiftUI accesible con `Cmd+,`.
- Crear `Views/Settings/SettingsView.swift` con tabs (General, Themes, Notifications, About) — los tabs concretos dependen de specs futuros y se documentan como placeholders.
- Crear `Models/AppSettings.swift` (`ObservableObject`) como contenedor de preferencias inyectado vía `@EnvironmentObject` o pasado por referencia al `AppDelegate`.
- Persistencia con `@AppStorage` en cada vista que lo necesite, agrupados bajo namespace `liquidNotch.*`.
- Persistir `selectedTheme` (placeholder para spec 06): `liquidNotch.theme`.
- Persistir `expandOnHover` (default `true`): `liquidNotch.expandOnHover`.
- Click derecho sobre la cápsula (collapsed o expanded) → `NSMenu` con ítems "Settings…" (`Cmd+,`), "Toggle LiquidNotch" y "Quit LiquidNotch" (`Cmd+Q`).
- Botón de engranaje (`gearshape.fill`) en la esquina superior derecha del estado expandido que abre Settings.
- `INFOPLIST_KEY_LSUIElement = YES` en Debug y Release del `.pbxproj` para asegurar accessory mode (ya está `setActivationPolicy(.accessory)` en código).
- Verificar que `NSApp.setActivationPolicy(.accessory)` se sigue invocando en `AppDelegate.applicationDidFinishLaunching`.

### Excluido

- **Implementación de los tabs individuales** (Themes, Notifications, etc.) — cada uno es su propio spec (06, 09).
- **Hotkey global configurable** (ej. `Ctrl+Cmd+N` para mostrar/ocultar) — fuera de alcance, se difiere.
- **Sincronización vía iCloud** de Settings — fuera de alcance.
- **Ventana de About personalizada** con créditos extendidos — solo placeholder en este spec.
- **Settings buscables con Spotlight** — fuera de alcance.
- **Multi-ventana de Settings** (algunos apps abren múltiples ventanas del mismo panel) — fuera de alcance.
- **Reset to defaults** — fuera de alcance, se añade si se pide.
- **Import / export de configuración** — fuera de alcance.

## File Structure (cambios)

```text
LiquidNotch/
├── LiquidNotch/
│   ├── LiquidNotchApp.swift              # MODIFICAR — quitar MenuBarExtra, añadir Settings scene
│   ├── App/
│   │   └── AppDelegate.swift             # MODIFICAR — inyectar AppSettings, NSMenu right-click
│   ├── Models/
│   │   ├── AppSettings.swift             # NUEVO — ObservableObject
│   │   ├── NotchState.swift              # existente
│   │   └── TrackInfo.swift               # existente
│   └── Views/
│       ├── Settings/                     # NUEVO directorio
│       │   ├── SettingsView.swift        # NUEVO — contenedor con TabView
│       │   ├── GeneralSettingsView.swift # NUEVO — expand on hover, etc.
│       │   ├── ThemeSettingsView.swift   # NUEVO placeholder para spec 06
│       │   ├── NotificationsSettingsView.swift # NUEVO placeholder para spec 09
│       │   └── AboutSettingsView.swift   # NUEVO — versión, build, links
│       └── UnifiedNotchView.swift        # MODIFICAR — añadir botón ⚙
├── LiquidNotch.xcodeproj/
│   └── project.pbxproj                   # MODIFICAR — LSUIElement=YES
└── specs/
    └── 05-settings-panel-no-menubar.md   # este spec
```

## Data Model

### `AppSettings` (nuevo)

```swift
import Foundation
import Combine
import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("liquidNotch.expandOnHover") var expandOnHover: Bool = true
    @AppStorage("liquidNotch.theme") var themeRaw: String = NotchTheme.liquidGlass.rawValue

    var theme: NotchTheme {
        get { NotchTheme(rawValue: themeRaw) ?? .liquidGlass }
        set { themeRaw = newValue.rawValue }
    }
}
```

> **Nota**: `NotchTheme` se define formalmente en el spec 06. En este spec, se usa un tipo `enum` declarado en `Models/NotchTheme.swift` con dos casos placeholder `.liquidGlass` y `.solidBlack`, para que el spec 06 solo tenga que ampliarlo. Se documenta en **Decisiones**.

### Keys de `UserDefaults`

| Key | Tipo | Default | Descripción |
|---|---|---|---|
| `liquidNotch.expandOnHover` | `Bool` | `true` | Si la cápsula se expande automáticamente al hacer hover |
| `liquidNotch.theme` | `String` | `"liquidGlass"` | Tema activo (referencia a `NotchTheme.rawValue`) |

> Los specs 06 y 09 añadirán sus propias keys. La convención es `liquidNotch.<area>.<setting>`.

## Implementation Plan

### Fase 1 — `AppSettings` y `NotchTheme` placeholder

**Archivos nuevos**: `Models/AppSettings.swift`, `Models/NotchTheme.swift`.

```swift
// Models/NotchTheme.swift
import Foundation

enum NotchTheme: String, CaseIterable, Identifiable {
    case liquidGlass = "liquidGlass"
    case solidBlack = "solidBlack"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .liquidGlass: "Liquid Glass"
        case .solidBlack: "Solid Black"
        }
    }
}
```

`AppSettings` contiene los `@AppStorage` listados arriba. Se documenta en el header del archivo que cualquier nueva preferencia debe vivir aquí.

**Verificación**: el proyecto compila; `AppSettings()` se puede instanciar sin errores.

### Fase 2 — Inyectar `AppSettings` en el árbol SwiftUI

**Archivo**: `LiquidNotchApp.swift` (modificar).

Cambios:
1. Eliminar el `MenuBarExtra` por completo (líneas 8-17 del archivo actual).
2. Añadir `Settings { SettingsView() }` como nueva scene.
3. Crear `@StateObject private var settings = AppSettings()` en `LiquidNotchApp`.
4. Pasar `settings` al `AppDelegate` mediante un nuevo inicializador: `appDelegate.settings = settings` en el `init` del `App` o vía `@EnvironmentObject` en la `SettingsView`.
5. El `AppDelegate` recibe `settings: AppSettings?` y lo guarda para que `UnifiedNotchView` lo consuma.

```swift
@main
struct LiquidNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }

    init() {
        appDelegate.settings = AppSettings()
    }
}
```

> **Nota**: el `AppDelegate` mantiene su propia instancia de `AppSettings` para uso desde AppKit (NSMenu). La instancia en `@StateObject` se usa para la UI SwiftUI. Se sincronizan automáticamente vía `UserDefaults`. Se documenta en **Decisiones** por qué se duplica.

**Verificación**: `Cmd+,` abre la ventana de Settings; cerrarla y reabrirla funciona.

### Fase 3 — `SettingsView` con tabs

**Archivo nuevo**: `Views/Settings/SettingsView.swift`.

Layout: `TabView` con 4 tabs:
1. **General**: `GeneralSettingsView` (placeholder inicial con `Toggle("Expand on hover", isOn: $settings.expandOnHover)`).
2. **Theme**: `ThemeSettingsView` (placeholder, implementado en spec 06).
3. **Notifications**: `NotificationsSettingsView` (placeholder, implementado en spec 09).
4. **About**: `AboutSettingsView` con versión (`Bundle.main.infoDictionary?["CFBundleShortVersionString"]`), build, GitHub link, license link.

```swift
struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
            ThemeSettingsView()
                .tabItem { Label("Theme", systemImage: "paintbrush") }
            NotificationsSettingsView()
                .tabItem { Label("Notifications", systemImage: "bell") }
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 320)
    }
}
```

> El tamaño del frame (500x320) es el estándar de macOS para paneles de Settings con TabView (igual que Safari, Mail, etc.).

Cada `XxxSettingsView` placeholder contiene solo un `Text("Coming soon")` y, en el caso de `General`, el toggle mencionado.

**Verificación**: la ventana se abre con `Cmd+,`; los 4 tabs se ven; el toggle de General persiste al cerrar/reabrir.

### Fase 4 — Click derecho en la cápsula → `NSMenu`

**Archivo**: `App/AppDelegate.swift` (modificar).

Cambios:
1. Añadir `var settings: AppSettings?` como propiedad del `AppDelegate`.
2. Crear un `NSMenu` reutilizable con ítems:
   - **"Settings…"** → `NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)` con `keyEquivalent: ","`.
   - **"Toggle LiquidNotch"** → `appDelegate.toggleExpansion()`, `keyEquivalent: " "` (espacio) o ninguno.
   - **"Quit LiquidNotch"** → `NSApp.terminate(nil)`, `keyEquivalent: "q"`.
3. En `setupTrackingArea()`, además del `NSTrackingArea` existente para hover, añadir un `NSTrackingArea` para `rightMouseDown` (`.activeInActiveApp`).
4. Sobrescribir `rightMouseDown(with:)` en una subclase de `NSHostingView` (crear `NotchHostingView`) que llame a `NSMenu.popUp(positioning:at:in:)`.

> **Detalle crítico**: el tracking area existente usa `.mouseEnteredAndExited`. Para el menú contextual, una opción más limpia es usar `NSView.menu` (disponible desde macOS 14+), pero como el deployment target es 26.5, podemos usar la API moderna.

```swift
// AppDelegate.swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var settings: AppSettings?

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Toggle LiquidNotch", action: #selector(toggleExpansionMenu), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit LiquidNotch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    @objc func showSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc func toggleExpansionMenu() {
        toggleExpansion()
    }
}
```

> **Nota técnica**: `showSettingsWindow:` es el selector que `Settings` scene de SwiftUI implementa internamente. En algunas versiones de macOS se llama `showSettingsWindow:` y en otras `showPreferences:`. Si el primero no funciona, fallback a `NSApp.sendAction(Selector(("showPreferences:")), ...)`.

5. Pasar el menú al `NSHostingView` mediante `hostingView.menu = menu` en `createPanel()`.

**Verificación**: click derecho sobre la cápsula muestra el menú; seleccionar "Settings…" abre la ventana; seleccionar "Quit" cierra la app.

### Fase 5 — Botón ⚙ en la vista expandida

**Archivo**: `Views/UnifiedNotchView.swift` (modificar).

Cambios:
1. Cuando `notchState.isExpanded == true`, mostrar un `Button` con `Image(systemName: "gearshape.fill")` en la esquina superior derecha del `ExpandedContentView`.
2. La acción del botón: `NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)`.
3. Estilo: 16pt, color blanco al 60% de opacidad, sin fondo. Aumentar opacidad en hover (`@State private var settingsHovered = false`).

```swift
Button(action: { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }) {
    Image(systemName: "gearshape.fill")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.white.opacity(settingsHovered ? 0.95 : 0.6))
}
.buttonStyle(.plain)
.onHover { settingsHovered = $0 }
.padding(8)
```

Posición: esquina superior derecha del `ExpandedContentView`, offset `(0, -28)` respecto al `HStack` principal para que quede en la cápsula superior (la línea de 34pt de alto que ya tiene el `CapsuleBarView`).

**Verificación**: el botón aparece solo en expanded; click abre Settings; el hover cambia opacidad.

### Fase 6 — `LSUIElement = YES`

**Archivo**: `LiquidNotch.xcodeproj/project.pbxproj` (modificar con Xcode).

Pasos:
1. Abrir el proyecto.
2. Seleccionar el target `LiquidNotch`.
3. Pestaña **Info** → agregar/editar `Application is agent (UIElement)` = `YES`. Esto se refleja como `INFOPLIST_KEY_LSUIElement = YES` en las dos configuraciones (Debug y Release).
4. Verificar que el `.pbxproj` no contiene ya la línea con `NO` (debe reemplazarse, no duplicarse).

**Verificación**: tras build, la app no aparece en el Dock ni en la barra de menús (solo el NSPanel del notch). El switch de App (`Cmd+Tab`) sigue funcionando.

### Fase 7 — `expandOnHover` consumido por `AppDelegate`

**Archivo**: `App/AppDelegate.swift` (modificar).

Cambios:
1. En `NotchHoverHandler`, antes de llamar a `onHoverEnter?()`, verificar `appDelegate.settings?.expandOnHover ?? true`.
2. Si `expandOnHover == false`, `onHoverEnter` se ignora (pero `mouseExited` se sigue manejando para evitar estados inconsistentes).

```swift
// NotchHoverHandler
override func mouseEntered(with event: NSEvent) {
    guard let appDelegate = NSApp.delegate as? AppDelegate,
          appDelegate.settings?.expandOnHover ?? true else {
        return
    }
    hoverTimer?.invalidate()
    onHoverEnter?()
}
```

> **Detalle**: el botón ⚙ en expanded es la única forma de expandir manualmente si `expandOnHover` está en `false`. Se documenta en la UI de General.

**Verificación**: con `expandOnHover = false`, hacer hover sobre la cápsula NO la expande; con `true`, sí.

## Acceptance Criteria

- [ ] `LiquidNotch.xcodeproj` ya no contiene `INFOPLIST_KEY_LSUIElement = NO` (reemplazado por `= YES`).
- [ ] Tras build, la app no aparece en el Dock ni en la barra de menús (solo el NSPanel del notch).
- [ ] `Cmd+,` abre la ventana de Settings con 4 tabs.
- [ ] `Cmd+Q` cierra la app.
- [ ] Click derecho sobre la cápsula (collapsed o expanded) muestra `NSMenu` con 3 ítems.
- [ ] "Settings…" en el menú contextual abre la ventana de Settings.
- [ ] "Quit LiquidNotch" en el menú contextual cierra la app.
- [ ] El botón ⚙ aparece solo cuando `notchState.isExpanded == true`, en la esquina superior derecha.
- [ ] Click en ⚙ abre Settings.
- [ ] El toggle "Expand on hover" en Settings persiste tras cerrar y reabrir la app.
- [ ] Con `expandOnHover = false`, hacer hover NO expande la cápsula.
- [ ] Con `expandOnHover = true`, hacer hover expande la cápsula (comportamiento previo).
- [ ] El tab "About" muestra la versión correcta del bundle.
- [ ] Los placeholders de "Theme" y "Notifications" muestran un texto "Coming soon" o equivalente.
- [ ] La ventana de Settings se cierra con `Cmd+W` o con el botón rojo estándar.

## Decisiones tomadas

- **Sí: Settings scene de SwiftUI + `Cmd+,`** — estándar de macOS, accesible, sin código boilerplate.
- **No: NSWindow manual con `NSWindowController`** — más código, sin beneficio.
- **Sí: `TabView` con 4 tabs** — el más común para apps con varias áreas de configuración.
- **No: NavigationView / sidebar** — overengineering para 4 secciones.
- **Sí: `AppSettings` como `ObservableObject` con `@AppStorage`** — SwiftUI idiomático, sin código de sincronización.
- **Sí: Instancia duplicada de `AppSettings` en `AppDelegate`** — `AppDelegate` se inicializa antes que `@StateObject`, y `NSMenu` no puede consumir `@EnvironmentObject`. Sincronización vía `UserDefaults` (idempotente).
- **No: Singleton / `AppSettings.shared`** — anti-pattern en SwiftUI; `@StateObject` es la forma correcta para UI.
- **Sí: `NotchTheme` declarado en este spec con casos placeholder** — para que `AppSettings.theme` compile; el spec 06 amplía el enum.
- **No: Diferir la creación de `NotchTheme` al spec 06** — forzaría un cambio de archivos en dos specs, complica el diff.
- **Sí: `NSApp.sendAction(Selector(("showSettingsWindow:")), ...)`** — API privada de SwiftUI pero estable; documentada en foros de Apple Developer.
- **No: `NSApp.sendAction(Selector(("showPreferences:")), ...)`** — usado por AppKit pre-SwiftUI; puede no funcionar con `Settings` scene.
- **Sí: Click derecho vía `hostingView.menu`** — API moderna (macOS 14+), cero código custom.
- **No: Subclase de `NSHostingView` con `rightMouseDown`** — funciona pero más código; `menu` property es declarativa.
- **Sí: Frame fijo 500x320** — estándar de macOS para Settings con TabView.
- **No: Frame dinámico según tab** — UX inconsistente entre tabs.

## Riesgos

| Riesgo | Mitigación |
|---|---|
| `showSettingsWindow:` no funciona en alguna versión de macOS | Fallback a `showPreferences:`; documentar en el código con comentario explicativo |
| `INFOPLIST_KEY_LSUIElement = YES` rompe la activación de Settings scene | Verificar con un test manual: `Cmd+,` debe traer la app al frente |
| El menú contextual se dispara sobre los hijos del hosting view (no el panel) | Usar `hostingView.menu` que SwiftUI/AppKit propagan correctamente |
| `expandOnHover = false` deja la cápsula inaccesible para expandir | El botón ⚙ (solo visible en expanded) no ayuda; documentar que "Toggle LiquidNotch" del menú contextual sigue funcionando |
| `AppSettings` se duplica y se desincroniza | `@AppStorage` se respalda en `UserDefaults` que es global; lectura inmediata, no hay race condition |
| Settings scene es pesada y abre en ventana propia (no en el panel) | Es el comportamiento estándar de macOS; el usuario lo espera así |
| `Cmd+,` conflicto con otra app | Estándar de macOS, improbable; si pasa, se documenta en README |

## Verification final

```bash
# Build limpio
xcodebuild -project LiquidNotch.xcodeproj -scheme LiquidNotch -destination 'platform=macOS' clean build

# Verificar que LSUIElement quedó en YES
grep -c "INFOPLIST_KEY_LSUIElement = YES" LiquidNotch.xcodeproj/project.pbxproj  # debe imprimir 2 (Debug + Release)
grep -c "INFOPLIST_KEY_LSUIElement = NO" LiquidNotch.xcodeproj/project.pbxproj   # debe imprimir 0

# Verificar que MenuBarExtra desapareció
grep -c "MenuBarExtra" LiquidNotch/LiquidNotchApp.swift  # debe imprimir 0

# Verificar que las preferencias se persisten
defaults read kelevo.LiquidNotch liquidNotch.expandOnHover  # debe imprimir 1 (true) o 0 (false)
```

## What is **NOT** in this spec

- Implementación real de los tabs de Theme y Notifications (specs 06 y 09).
- Hotkey global configurable.
- Sincronización iCloud de Settings.
- About page con créditos extendidos.
- Reset to defaults.
- Import / export de configuración.
- Settings buscable con Spotlight.
- Multi-ventana de Settings.

Cada uno, si aterriza, va en su propio spec.
