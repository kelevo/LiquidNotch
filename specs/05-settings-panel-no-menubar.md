# Spec: 05 — Settings Panel y eliminación del MenuBarExtra

- **Estado**: Approved
- **Fecha**: 2026-10-08
- **Depende de**: Spec 04 (open source prep)
- **Autor**: opencode
- **Plataforma**: macOS only (Apple Silicon)

## Objetivos

Eliminar el `MenuBarExtra` que muestra el icono de LiquidNotch en la barra de menús del sistema y reemplazarlo por un panel de Settings accesible mediante dos puntos de entrada: el atajo estándar `Cmd+,` y un botón de engranaje en la vista expandida de la isla. La UI de Settings es una ventana macOS estándar con `NavigationSplitView` (sidebar), estilo NotchBox, preparada para crecer con specs futuros.

La app conserva icono en el Dock (decisión aceptada por el usuario para que `Cmd+,` funcione: `LSUIElement = NO`), pero no tiene ningún icono extra en la barra de menús (sin `MenuBarExtra`).

## Alcance (Scope)

### Incluido

- Eliminar el `MenuBarExtra` de `LiquidNotchApp.swift`.
- Crear `Window("Settings", id: "settings")` scene de SwiftUI accesible con `Cmd+,` (vía `CommandGroup(replacing: .appSettings)` con `keyboardShortcut(",")`).
- Crear `Views/Settings/SettingsView.swift` con `NavigationSplitView` + sidebar de 4 entradas (General, Theme, Notifications, About) — las entradas concretas de specs futuros se documentan como placeholders.
- Crear `Models/AppSettings.swift` (`ObservableObject`) como contenedor de preferencias inyectado vía `@EnvironmentObject`.
- Crear `Models/SettingsOpener.swift` con `Notification.Name.openSettings` como única vía de abrir Settings desde cualquier punto de la app (⚙ del menú App y ⚙ de la isla).
- Persistencia con `@AppStorage` en cada vista que lo necesite, agrupados bajo namespace `liquidNotch.*`.
- Persistir `selectedTheme` (placeholder para spec 06): `liquidNotch.theme`.
- Persistir `expandOnHover` (default `true`): `liquidNotch.expandOnHover`.
- Botón de engranaje (`gearshape.fill`) en la esquina superior derecha del estado expandido que abre Settings vía `NotificationCenter`.
- `INFOPLIST_KEY_LSUIElement = NO` en Debug y Release del `.pbxproj` (el binario generado tiene `LSUIElement => false`; el icono en el Dock puede no refrescarse por caché de LaunchServices — ver Riesgos). **Eliminar** la llamada programática `NSApp.setActivationPolicy(.accessory)`: sobreescribía el plist en runtime y rompía Dock icon y atajos.
- Reducir `AppDelegate` a lifecycle del panel: eliminar `var settings`, `makeContextMenu`, `showSettings`, `toggleExpansionMenu` y `hostingView.menu`.
- Reservar 36pt de hueco en `CapsuleBarView` cuando expanded, para que el ⚙ no se solape con el `MiniEqualizerView`.
- Botón "Quit LiquidNotch" destructivo prominente en el tab About (vía de salida principal).

### Excluido

- **Implementación de las entradas individuales** (Theme, Notifications, etc.) — cada uno es su propio spec (06, 09).
- **Menú contextual de click derecho sobre la cápsula** — eliminado del alcance por decisión de UX (el ⚙ es el único entry point visible en la isla; ver Decisiones).
- **Hotkey global configurable** (ej. `Ctrl+Cmd+N` para mostrar/ocultar) — fuera de alcance, se difiere.
- **Sincronización vía iCloud** de Settings — fuera de alcance.
- **Ventana de About personalizada** con créditos extendidos — solo placeholder en este spec.
- **Settings buscables con Spotlight** — fuera de alcance.
- **Multi-ventana de Settings** (algunas apps abren múltiples ventanas del mismo panel) — fuera de alcance.
- **Reset to defaults** — fuera de alcance, se añade si se pide.
- **Import / export de configuración** — fuera de alcance.

## File Structure (cambios)

```text
LiquidNotch/
├── LiquidNotch/
│   ├── LiquidNotchApp.swift              # MODIFICAR — quitar MenuBarExtra, añadir Window scene + Commands
│   ├── App/
│   │   └── AppDelegate.swift             # MODIFICAR — eliminar Settings/menú contextual, fix hover
│   ├── Models/
│   │   ├── AppSettings.swift             # NUEVO — ObservableObject
│   │   ├── NotchTheme.swift              # NUEVO — enum placeholder
│   │   ├── SettingsOpener.swift          # NUEVO — Notification.Name.openSettings
│   │   ├── NotchState.swift              # existente
│   │   └── TrackInfo.swift               # existente
│   └── Views/
│       ├── Settings/                     # NUEVO directorio
│       │   ├── SettingsView.swift        # NUEVO — NavigationSplitView con sidebar
│       │   ├── GeneralSettingsView.swift # NUEVO — expand on hover, etc.
│       │   ├── ThemeSettingsView.swift   # NUEVO placeholder para spec 06
│       │   ├── NotificationsSettingsView.swift # NUEVO placeholder para spec 09
│       │   └── AboutSettingsView.swift   # NUEVO — versión, build, links
│       └── UnifiedNotchView.swift        # MODIFICAR — botón ⚙ abre Settings vía NotificationCenter
├── LiquidNotch.xcodeproj/
│   └── project.pbxproj                   # MODIFICAR — LSUIElement=NO
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

### `SettingsOpener` (nuevo)

```swift
import Foundation

extension Notification.Name {
    static let openSettings = Notification.Name("kelevo.LiquidNotch.openSettings")
}
```

> Único canal de "abrir Settings". Cualquier punto de la app (⚙ de la isla, ítem "Settings…" del menú App, futuros entry points) hace `NotificationCenter.default.post(name: .openSettings, object: nil)`. El root de la `Window` scene escucha y llama `openWindow(id: "settings")`.

### Keys de `UserDefaults`

| Key | Tipo | Default | Descripción |
|---|---|---|---|
| `liquidNotch.expandOnHover` | `Bool` | `true` | Si la cápsula se expande automáticamente al hacer hover |
| `liquidNotch.theme` | `String` | `"liquidGlass"` | Tema activo (referencia a `NotchTheme.rawValue`) |

> Los specs 06 y 09 añadirán sus propias keys. La convención es `liquidNotch.<area>.<setting>`.

## Implementation Plan

### Fase 1 — `AppSettings`, `NotchTheme` y `SettingsOpener`

**Archivos nuevos**: `Models/AppSettings.swift`, `Models/NotchTheme.swift`, `Models/SettingsOpener.swift`.

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

### Fase 2 — `LiquidNotchApp.swift` con `Window` scene + `Commands`

**Archivo**: `LiquidNotchApp.swift` (reescribir).

Cambios:
1. Eliminar el `MenuBarExtra` por completo.
2. Eliminar `init() { appDelegate.settings = AppSettings() }` (ya no existe `appDelegate.settings`).
3. Añadir `Window("Settings", id: "settings")` scene con `SettingsRootView().environmentObject(settings).frame(minWidth: 600, minHeight: 440)` y `.windowResizability(.contentSize)`.
4. Añadir `commands { CommandGroup(replacing: .appSettings) { SettingsMenuButton() } }` donde `SettingsMenuButton` es un `View` con `@Environment(\.openWindow)` y `Button("Settings…") { openWindow(id: "settings") }.keyboardShortcut(",")`.
5. Mantener `@NSApplicationDelegateAdaptor(AppDelegate.self)` (el `AppDelegate` sigue gestionando el panel).

```swift
@main
struct LiquidNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        Window("Settings", id: "settings") {
            SettingsRootView()
                .environmentObject(settings)
                .frame(minWidth: 600, minHeight: 440)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsMenuButton()
            }
        }
    }
}
```

**Verificación**: `Cmd+,` abre la ventana de Settings; cerrarla y reabrirla funciona; el ítem "Settings…" aparece en el menú App.

### Fase 3 — `SettingsView` como `NavigationSplitView` con sidebar

**Archivo nuevo**: `Views/Settings/SettingsView.swift` (renombrado lógicamente a `SettingsRootView`, puede mantener el nombre del archivo).

Layout: `NavigationSplitView` con `List` sidebar y `.onReceive` para escuchar `Notification.Name.openSettings` y llamar `openWindow(id: "settings")`.

- `@EnvironmentObject var settings: AppSettings`
- `@Environment(\.openWindow) private var openWindow`
- `@State private var selection: SettingsSection = .general`

Sidebar (4 entradas con systemImage):
1. **General** (gear) → `GeneralSettingsView` (con `Toggle("Expand on hover", isOn: $settings.expandOnHover)`).
2. **Theme** (paintbrush) → `ThemeSettingsView` (placeholder, implementado en spec 06).
3. **Notifications** (bell) → `NotificationsSettingsView` (placeholder, implementado en spec 09).
4. **About** (info.circle) → `AboutSettingsView` (versión, build, links).

Frame: `minWidth: 600, minHeight: 440` aplicado en la `Window` scene (no en el `NavigationSplitView`, que se adapta al contenido).

```swift
struct SettingsRootView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.openWindow) private var openWindow
    @State private var selection: SettingsSection = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("General", systemImage: "gear").tag(SettingsSection.general)
                Label("Theme", systemImage: "paintbrush").tag(SettingsSection.theme)
                Label("Notifications", systemImage: "bell").tag(SettingsSection.notifications)
                Label("About", systemImage: "info.circle").tag(SettingsSection.about)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch selection {
            case .general: GeneralSettingsView()
            case .theme: ThemeSettingsView()
            case .notifications: NotificationsSettingsView()
            case .about: AboutSettingsView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            openWindow(id: "settings")
        }
    }
}
```

`SettingsMenuButton` se define en el mismo archivo:

```swift
struct SettingsMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings…") {
            openWindow(id: "settings")
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}
```

Cada `XxxSettingsView` placeholder contiene solo un `Text("Coming soon")` y, en el caso de `General`, el toggle mencionado.

**Verificación**: la ventana se abre con `Cmd+,`; la sidebar muestra 4 entradas; el detalle cambia al seleccionar; el toggle de General persiste al cerrar/reabrir.

### Fase 4 — Limpiar `AppDelegate` (eliminar menú contextual y `settings`)

**Archivo**: `App/AppDelegate.swift` (modificar).

Cambios:
1. Eliminar `var settings: AppSettings?`.
2. Eliminar `makeContextMenu()`, `showSettings()`, `toggleExpansionMenu()` y `hostingView.menu = makeContextMenu()` en `createPanel()`.
3. Mantener: `applicationDidFinishLaunching` (sin `setActivationPolicy`, ver Decisiones), `applicationShouldTerminateAfterLastWindowClosed`, `createPanel`, `positionPanel`, `setupTrackingArea`, `expand`, `collapse`, `scheduleCollapseIfNeeded`, `cancelCollapseIfNeeded`, `toggleExpansion`.

**Verificación**: el proyecto compila; `grep -c 'hostingView.menu\|makeContextMenu' LiquidNotch/App/AppDelegate.swift` = 0.

### Fase 5 — Botón ⚙ abre Settings vía `NotificationCenter`

**Archivo**: `Views/UnifiedNotchView.swift` (modificar).

Cambios:
1. Cuando `notchState.isExpanded == true`, mostrar un `Button` con `Image(systemName: "gearshape.fill")` en la esquina superior derecha del `ExpandedContentView` (offset `(0, -28)` respecto al `HStack` principal).
2. La acción del botón: `NotificationCenter.default.post(name: .openSettings, object: nil)`.
3. Estilo: 14pt, color blanco al 60% de opacidad, sin fondo. Aumentar opacidad en hover (`@State private var settingsHovered = false`).

```swift
Button(action: { NotificationCenter.default.post(name: .openSettings, object: nil) }) {
    Image(systemName: "gearshape.fill")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.white.opacity(settingsHovered ? 0.95 : 0.6))
}
.buttonStyle(.plain)
.onHover { settingsHovered = $0 }
.padding(8)
```

**Verificación**: el botón aparece solo en expanded; click abre Settings; el hover cambia opacidad.

### Fase 6 — `LSUIElement = NO`

**Archivo**: `LiquidNotch.xcodeproj/project.pbxproj` (modificar).

Cambios:
1. En ambas configuraciones (Debug y Release), `INFOPLIST_KEY_LSUIElement = YES` → `INFOPLIST_KEY_LSUIElement = NO`.

**Verificación**: tras build, la app aparece en el Dock. El menú App estándar está disponible (con `Cmd+,` funcional). No hay icono extra en la menubar (sin `MenuBarExtra`).

### Fase 7 — `expandOnHover` leído directamente de `UserDefaults`

**Archivo**: `App/AppDelegate.swift` (modificar).

Cambios:
1. En `NotchHoverHandler.mouseEntered`, reemplazar la guarda por lectura directa de `UserDefaults`:
   ```swift
   override func mouseEntered(with event: NSEvent) {
       let expandOnHover = UserDefaults.standard.object(forKey: "liquidNotch.expandOnHover") as? Bool ?? true
       guard expandOnHover else { return }
       hoverTimer?.invalidate()
       hoverTimer = nil
       onHoverEnter?()
   }
   ```
2. Justificación: `NotchHoverHandler` es `NSResponder` (no `@MainActor` explícito pero con aislamiento implícito del proyecto). Acceder a `AppSettings` `@MainActor` desde aquí era problemático (síntoma 3 del test: hover no expandía). `UserDefaults.standard` es thread-safe y no requiere actor.

**Verificación**: con `expandOnHover = false`, hacer hover sobre la cápsula NO la expande; con `true`, sí.

> **Detalle**: el botón ⚙ en expanded es la única forma de expandir manualmente si `expandOnHover` está en `false`. Se documenta en la UI de General.

## Acceptance Criteria

- [ ] `LiquidNotch.xcodeproj` contiene `INFOPLIST_KEY_LSUIElement = NO` en Debug y Release.
- [ ] Tras build, la app no tiene icono extra en la barra de menús (sin `MenuBarExtra`; solo el menú App estándar con "AppName ▸"). El icono en el Dock puede no aparecer en todos los entornos de prueba (caché de LaunchServices); verificar con `plutil -p <app>/Contents/Info.plist | grep LSUIElement` que devuelve `false`.
- [ ] `AppDelegate.applicationDidFinishLaunching` NO invoca `setActivationPolicy(.accessory)` (el plist `LSUIElement = NO` rige sin override programático).
- [ ] `Cmd+,` abre la ventana de Settings con sidebar (General, Theme, Notifications, About).
- [ ] `Cmd+W` cierra la ventana de Settings.
- [ ] `Cmd+Q` cierra la app.
- [ ] El botón "Quit LiquidNotch" en el tab About (destructivo prominente) cierra la app al hacer click.
- [ ] El botón ⚙ aparece solo cuando `notchState.isExpanded == true`, en la esquina superior derecha.
- [ ] Click en ⚙ abre Settings.
- [ ] El toggle "Expand on hover" en Settings persiste tras cerrar y reabrir la app.
- [ ] Con `expandOnHover = false`, hacer hover NO expande la cápsula.
- [ ] Con `expandOnHover = true`, hacer hover expande la cápsula (comportamiento previo).
- [ ] El ítem "About" de la sidebar muestra la versión correcta del bundle.
- [ ] El botón ⚙ no se solapa con el `MiniEqualizerView` (el `CapsuleBarView` reserva 36pt de hueco cuando expanded).
- [ ] Los placeholders de "Theme" y "Notifications" muestran un texto "Coming soon" o equivalente.
- [ ] La ventana de Settings se cierra con `Cmd+W` o con el botón rojo estándar.
- [ ] `grep -c 'MenuBarExtra' LiquidNotch/LiquidNotchApp.swift` = 0.
- [ ] `grep -c 'hostingView.menu\|makeContextMenu' LiquidNotch/App/AppDelegate.swift` = 0.
- [ ] El click derecho sobre la cápsula NO muestra ningún menú contextual (comportamiento eliminado por decisión de UX).

## Decisiones tomadas

- **Sí: `Window` scene con `id: "settings"` + `openWindow`** — ventana única, abrible/cerrable a demanda, sin selectores mágicos.
- **No: `Settings` scene** — su ventana no es inspeccionable/fiable y depende de `LSUIElement = NO` + menú App; `Window` da control explícito.
- **Sí: `NavigationSplitView` con sidebar (estilo NotchBox)** — escala con specs futuros (06, 09, y los que vengan); la referencia NotchBox usa este patrón.
- **No: `TabView`** — menos flexible para añadir muchas secciones; el spec original lo elegía por "4 secciones", pero la app crecerá.
- **Sí: `LSUIElement = NO` (Dock icon)** — requisito para que `Cmd+,` funcione (menú App estándar disponible). El usuario aceptó el Dock icon ("No, no tengo problema con que se muestre en el dock").
- **No: `LSUIElement = YES` (accessory mode puro)** — impedía `Cmd+,` (sin menú App = sin atajo). Se documenta como trade-off en Riesgos.
- **Sí: `NotificationCenter` + `Notification.Name.openSettings` como única vía de abrir Settings** — uniforme: el ⚙ de la isla, el ítem "Settings…" del menú App, y futuros entry points usan el mismo mecanismo; el root de la `Window` escucha y llama `openWindow`.
- **No: `NSApp.sendAction(Selector(("showSettingsWindow:")), ...)`** — selector privado de SwiftUI, frágil; `openWindow(id:)` es API pública.
- **No: `hostingView.menu` / menú contextual de click derecho** — eliminado por decisión de UX del usuario (P3: "No, deja un icono de engrane en la isla expandida… al dar click en ese icono, manda a la configuracion"). El ⚙ es el único entry point visible en la isla.
- **Sí: `AppSettings` como `ObservableObject` con `@AppStorage`** — SwiftUI idiomático, sin código de sincronización. Solo una instancia (en `@StateObject` de la App); no se duplica en `AppDelegate`.
- **No: Singleton / `AppSettings.shared`** — anti-pattern en SwiftUI; `@StateObject` es la forma correcta para UI.
- **Sí: `NotchTheme` declarado en este spec con casos placeholder** — para que `AppSettings.theme` compile; el spec 06 amplía el enum.
- **No: Diferir la creación de `NotchTheme` al spec 06** — forzaría un cambio de archivos en dos specs, complica el diff.
- **Sí: Frame 600x440** — estándar para Settings con sidebar (NotchBox usa ~900x600; 600x440 es el mínimo cómodo para sidebar + detail).
- **No: Frame 500x320** — pensado para `TabView`, queda pequeño con sidebar.
- **Sí: Hover fix leyendo `UserDefaults.standard` directamente** — evita el problema de actor isolation (`AppSettings` `@MainActor` leído desde `NSResponder`); síntoma 3 del test inicial (hover no expandía).
- **No: Acceder a `appDelegate.settings?.expandOnHover` desde `NotchHoverHandler`** — causaba que el hover no funcionara.
- **Sí: Eliminar `setActivationPolicy(.accessory)` de `applicationDidFinishLaunching`** — con `LSUIElement = NO` en el plist, la llamada programática forzaba accessory y anulaba el plist: la app no aparecía en Dock y los atajos (`Cmd+,`, `Cmd+W`, `Cmd+Q`) no llegaban. El plist es la única fuente de verdad.
- **No: Mantener `setActivationPolicy(.accessory)`** — sobreescribía el `LSUIElement = NO` en runtime y rompía los atajos del menú App.
- **Sí: Reservar 36pt con `Spacer().frame(width: 36)` en `CapsuleBarView` cuando expanded** — el botón ⚙ (overlay top-trailing del `ExpandedContentView`) se solapaba con el `MiniEqualizerView` del bar; el hueco los separa sin mover el ⚙ de su posición (esquina superior derecha, según decisión original).
- **No: Mover el ⚙ a otra posición** — el spec lo pone en la esquina superior derecha; se ajusta el layout del bar, no el del botón.
- **Sí: Ocultar `MiniEqualizerView` cuando la cápsula está expanded** — junto al ⚙ no se ve estético (decisión del usuario tras test manual). En collapsed sigue visible.
- **Sí: Botón "Quit LiquidNotch" en el tab About con `Button(role: .destructive)` + `.buttonStyle(.borderedProminent)`** — vía principal de salida, dado que no hay menú contextual de click derecho (P3). Acción terminal → `role: .destructive` pinta el botón en rojo de forma nativa.
- **No: Reintroducir el menú contextual de click derecho solo para "Quit"** — contradice la decisión P3 (UX del usuario); el spec 08 podrá evaliarlo si se pide.
- **No: Forzar `NSApp.setActivationPolicy(.regular)` para garantizar el Dock icon** — el usuario aceptó que el Dock icon puede no aparecer en todo entorno de prueba (caché de LaunchServices / relanzado vía CLI). El plist generado confirma `LSUIElement => false` (`plutil -p … | grep LSUIElement`), así que la app está bien configurada; no se sobreescribe el plist con código.
- **Sí (estado actual, consciente): Botón "Quit LiquidNotch" en azul** — `Button(role: .destructive)` con `.buttonStyle(.borderedProminent)` rinde en el accent color global de la app (azul) en macOS 26.5, no en rojo. Aceptado por el usuario. Pendiente: si se prefiere rojo explícito, cambiar a `.buttonStyle(.bordered)` con `role: .destructive` o añadir `.tint(.red)`.

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Dock icon ausente en algunos entornos (aunque `plutil` confirma `LSUIElement => false`) | Atribuido a caché de LaunchServices o relanzado vía CLI; no bloqueante para el usuario. Fix futuro si se necesita: `lsregister -kill -r …` o `setActivationPolicy(.regular)` (decisión consciente de no aplicarlo). |
| Botón Quit en azul (no rojo) | `.borderedProminent` usa el accent color global; aceptado por el usuario. Pendiente de rojo explícito si cambia la preferencia. |
| Dock icon visible (contradice el "accessory mode" original) | Trade-off aceptado explícitamente por el usuario para que `Cmd+,` funcione; documentado en este spec. |
| Menú App estándar ocupa ~24pt en la menubar | Sin icono extra (sin `MenuBarExtra`); solo "AppName ▸" mínimo. Aceptado por el usuario. |
| `openWindow(id: "settings")` no trae la ventana al frente si ya está abierta | `Window` scene en macOS la trae al frente automáticamente (comportamiento estándar); verificar con test manual. |
| `Notification.Name.openSettings` no llega al root si la `Window` no está montada | La `Window` scene está siempre montada (es la única scene de la app); `onReceive` siempre activo. |
| El `expandOnHover = false` deja la cápsula inaccesible para expandir | El botón ⚙ (solo visible en expanded) no ayuda; documentar en la UI de General que "Toggle LiquidNotch" del menú App sigue funcionando (o usar `Cmd+Tab` + click en Dock). |
| El click derecho no muestra menú (comportamiento eliminado) | Decisión de UX (P3); el ⚙ es el entry point canónico. Si se pide el menú contextual, añadirlo en un spec futuro. |
| `CommandGroup(replacing: .appSettings)` no reemplaza el ítem si `LSUIElement = NO` cambia el menú | Verificar con test manual que "Settings…" aparece y `Cmd+,` funciona. |
| `NavigationSplitView` con solo 4 entradas queda con sidebar ancho | `navigationSplitViewColumnWidth(min: 180, ideal: 200)` acota; el detail se adapta. |

## Verification final

```bash
# Build limpio
xcodebuild -project LiquidNotch.xcodeproj -scheme LiquidNotch -destination 'platform=macOS' clean build

# Verificar que LSUIElement quedó en NO
grep -c "INFOPLIST_KEY_LSUIElement = NO" LiquidNotch.xcodeproj/project.pbxproj  # debe imprimir 2 (Debug + Release)
grep -c "INFOPLIST_KEY_LSUIElement = YES" LiquidNotch.xcodeproj/project.pbxproj  # debe imprimir 0

# Verificar que MenuBarExtra desapareció
grep -c "MenuBarExtra" LiquidNotch/LiquidNotchApp.swift  # debe imprimir 0

# Verificar que el menú contextual se eliminó
grep -c "hostingView.menu\|makeContextMenu" LiquidNotch/App/AppDelegate.swift  # debe imprimir 0

# Verificar que SettingsOpener existe
grep -c "openSettings" LiquidNotch/Models/SettingsOpener.swift  # debe imprimir al menos 1

# Verificar que el override programático de activation policy desapareció
grep -c "setActivationPolicy" LiquidNotch/App/AppDelegate.swift  # debe imprimir 0

# Verificar que las preferencias se persisten
defaults read kelevo.LiquidNotch liquidNotch.expandOnHover  # debe imprimir 1 (true) o 0 (false)
```

## What is **NOT** in this spec

- Implementación real de las entradas de Theme y Notifications (specs 06 y 09).
- Menú contextual de click derecho (eliminado por decisión de UX).
- Hotkey global configurable.
- Sincronización iCloud de Settings.
- About page con créditos extendidos.
- Reset to defaults.
- Import / export de configuración.
- Settings buscable con Spotlight.
- Multi-ventana de Settings.

Cada uno, si aterriza, va en su propio spec.
