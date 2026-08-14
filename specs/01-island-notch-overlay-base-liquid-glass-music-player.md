# Spec: 01 — Island Notch Overlay Base & Liquid Glass Music Player

- **Estado**: En progreso
- **Fecha**: 2026-08-14
- **Depende de**: N/A (Proyecto base)
- **Autor**: opencode
- **Plataforma**: macOS only (Apple Silicon)

## Objetivos
- Crear una aplicación ligera para macOS nativa (SwiftUI/AppKit) que renderice una ventana flotante fija en el área del notch de la pantalla.
- En estado **colapsado**, mostrar un widget compacto (cover art + forma de onda / ecualizador).
- En estado **expandido** (trigger por hover), animar suavemente hacia una tarjeta estilizada con efecto *Liquid Glass* (translucidez tipo `.ultraThinMaterial` / Glassmorphism) que integre los controles de medios activos del sistema (portada, título, artista, tiempo de reproducción, slider y controles prev/pause/next).

## Alcance (Scope)
### Incluido
- Configuración de `NSPanel` transparente de AppKit con nivel flotante `.statusBar` (siempre arriba, sin sombra de ventana por defecto, sin bordes de ventana nativos).
- Detección del notch mediante `NSScreen.main` para posicionamiento absoluto superior-centro.
- Modos de vista en SwiftUI:
  - **Collapsed View**: Ancho compacto (~220px), fondo negro sólido/translúcido con bordes redondeados (`CornerRadius: 20`), portada miniatura (32x32) y mini visualizador dinámico.
  - **Expanded View**: Ancho/Alto expandido (~360px x 180px), fondo traslúcido con efecto *Liquid Glass* (`.ultraThinMaterial` + borde suave sutil `rgba(255,255,255,0.2)`), portada (100x100 con bordes redondeados), metadata de canción (título y artista), barra de progreso del tiempo y controles multimedia.
- Transición fluida con animación spring (`.spring(response: 0.35, dampingFraction: 0.75)`).
- Interacción hover con `onHover` y temporizador de salida (debounce 800ms) para evitar cierres accidentales al mover el cursor.
- Integración con Apple Music via `MPMusicPlayerController` (framework `MediaPlayer`).
- Soporte Spotify via AppleScript (`NSAppleScript`) como fallback secundario.

### Excluido
- Módulo de descargas activas y notificaciones avanzadas del sistema (se difieren a SPEC 02).
- Menú de configuraciones o preferencias persistentes en disco (`UserDefaults`).
- Distribución o firma con Apple Developer Account (App Sandbox / Notarización) — ejecutable para desarrollo/uso local o release en GitHub sin firmar.
- Compatibilidad con arquitecturas Intel antiguas (enfocado exclusivamente en Apple Silicon M-Series).
- Targets iOS y visionOS (este spec es macOS-only; los targets permanecen en el proyecto pero no se usan en esta fase).

## Diseño
### Referencia visual
Basado en mockups adjuntos del usuario:
1. **Collapsed Notch**: Pista activa con mini portada cuadrada a la izquierda, barra negra pulida y ecualizador animado a la derecha.
2. **Expanded Liquid Glass**: Tarjeta flotante con efecto cristalino frosted, portada en tamaño completo (izquierda), info del tema y slider de progreso (derecha), y panel de control flotante (Anterior, Pausa/Play, Siguiente) al centro-inferior.

### Paleta y Estilos
- Fondo colapsado: `Color.black.opacity(0.95)`
- Fondo expandido: `.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))`
- Borde glass: `RoundedRectangle` con `strokeBorder(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)`
- Sombras: `shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 10)`
- Tipografía: San Francisco / System Font (`.system(size: ..., weight: .semibold)`)

## Structure & Data Model

### File Structure
```text
LiquidNotch/
├── LiquidNotchApp.swift          # Entry point — NSApplicationDelegateAdaptor
├── App/
│   └── AppDelegate.swift         # NSPanel transparente, posicionamiento en notch
├── Views/
│   ├── MainNotchView.swift       # Contenedor con lógica hover + animación de resize
│   ├── CollapsedNotchView.swift  # Barra negra estilo Notch compacto (~220x44)
│   ├── ExpandedGlassView.swift   # Tarjeta glassmorphic (~360x180)
│   └── MiniEqualizerView.swift   # Visualizador de barras animadas (collapsed)
├── Services/
│   └── MediaRemoteManager.swift  # Observador Now Playing (MediaPlayer + AppleScript)
└── Models/
    └── TrackInfo.swift           # Struct: title, artist, artworkImage, duration, elapsedTime, isPlaying
```

### Data Model
```swift
struct TrackInfo: Equatable {
    let title: String
    let artist: String
    let artworkImage: NSImage?
    let duration: TimeInterval
    var elapsedTime: TimeInterval
    var isPlaying: Bool
}
```

## Technical Constraints

| Constraint | Detail |
|---|---|
| **Actor isolation** | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — todo el código es `@MainActor` por defecto. Servicios de background necesitan `nonisolated` o actores dedicados. |
| **File sync** | `PBXFileSystemSynchronizedRootGroup` — archivos se auto-sincronizan. NO editar `project.pbxproj` para agregar/eliminar archivos. |
| **Info.plist** | `GENERATE_INFOPLIST_FILE = YES` — auto-generado. No existe archivo `.plist` manual. |
| **No entitlements** | Sin App Sandbox para esta fase. |
| **Swift version** | Swift 5.0 con `SWIFT_APPROACHABLE_CONCURRENCY = YES`. |

## NSPanel Configuration

```swift
// AppDelegate.swift — configuración del panel
let panel = NSPanel(
    contentRect: NSRect(x: 0, y: 0, width: 220, height: 44),
    styleMask: [.nonactivatingPanel, .borderless],
    backing: .buffered,
    defer: false
)
panel.level = .statusBar
panel.isOpaque = false
panel.backgroundColor = .clear
panel.hasShadow = false
panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
panel.isMovableByWindowBackground = false
```

### Notch Detection
```swift
// Posicionar centrado sobre el notch
guard let screen = NSScreen.main else { return }
let screenFrame = screen.frame
let notchX = screenFrame.midX - (panelWidth / 2)
let notchY = screenFrame.maxY - panelHeight  // Pegado al borde superior
panel.setFrameOrigin(NSPoint(x: notchX, y: notchY))
```

## Media Service Strategy

### Apple Music (primario)
- Framework: `MediaPlayer` → `MPMusicPlayerController.systemMusicPlayer`
- Observar `playbackState` via `NotificationCenter` (`.MPMusicPlayerControllerPlaybackStateDidChange`)
- Extraer `nowPlayingItem` → title, artist, artwork, duration, playbackTime
- Timer para actualizar `elapsedTime` cada segundo mientras reproduce
- Controles: `.skipToNextItem()`, `.play()`, `.pause()`, `.skipToPreviousItem()`

### Spotify (fallback via AppleScript)
- Leer track info: `NSAppleScript` con `tell application "Spotify" to get {name, artist, artwork url} of current track`
- Controles: `play`, `pause`, `next track`, `previous track` via AppleScript
- Polling cada 1-2 segundos (Spotify no expone notifications en macOS)

## Implementation Phases

### Fase 1 — Foundation: NSPanel + AppDelegate
**Archivos**: `LiquidNotchApp.swift` (modificar), `App/AppDelegate.swift` (crear)
- Crear `NSPanel` transparente flotante con configuración descrita arriba
- Añadir `@NSApplicationDelegateAdaptor(AppDelegate.self)` al entry point
- Reemplazar `WindowGroup` con scene vacío (la ventana la maneja AppKit)
- Detectar notch y posicionar panel centrado
- **Verificación**: Build + run → ventana transparente visible sobre el notch

### Fase 2 — Data Model
**Archivo**: `Models/TrackInfo.swift` (crear)
- Struct `TrackInfo` con campos descritos arriba

### Fase 3 — Media Service
**Archivo**: `Services/MediaRemoteManager.swift` (crear)
- `ObservableObject` con `@Published var currentTrack: TrackInfo?`
- Implementar Apple Music primero (`MPMusicPlayerController`)
- Implementar Spotify via AppleScript como segundo paso
- Timer de actualización de `elapsedTime`

### Fase 4 — Collapsed View
**Archivos**: `Views/CollapsedNotchView.swift`, `Views/MiniEqualizerView.swift` (crear)
- `HStack`: cover 32x32 (rounded 6px) + título truncado + mini ecualizador
- Fondo `Color.black.opacity(0.95)` con `RoundedRectangle(cornerRadius: 20)`
- `MiniEqualizerView`: 4-5 barras con `TimelineView(.animation)`, visible solo cuando `isPlaying`

### Fase 5 — Expanded View (Liquid Glass)
**Archivo**: `Views/ExpandedGlassView.swift` (crear)
- `.ultraThinMaterial` background + borde glass gradient + sombra
- Layout: cover 100x100 (izq) | título + artista + slider + tiempos (der) | controles (inferior centro)
- Botones: `backward.fill`, `play.fill`/`pause.fill`, `forward.fill` (SF Symbols)

### Fase 6 — Main Container + Hover Logic
**Archivo**: `Views/MainNotchView.swift` (crear)
- `@State isExpanded` + `@State hoverTimer: Timer?`
- Hover in → cancelar timer, expand con `.spring(response: 0.35, dampingFraction: 0.75)`
- Hover out → timer 800ms debounce → colapsar
- Redimensionar `NSPanel` via referencia a `AppDelegate` (callback o `NotificationCenter`)

### Fase 7 — Integration + Cleanup
- Eliminar `ContentView.swift`
- Conectar `MediaRemoteManager` como `@StateObject` en `MainNotchView`
- Pasar `TrackInfo` a collapsed y expanded views
- Wire up controles multimedia a `MPMusicPlayerController` / AppleScript
- Recalcular posición del `NSPanel` al cambiar de tamaño (centrar respecto al notch)
- **Verificación final**: Build + run → hover sobre notch expande tarjeta glass con música activa

## Open Questions

| # | Tema | Decisión pendiente |
|---|---|---|
| 1 | **Targets iOS/visionOS** | ¿Eliminar del proyecto o mantener inactivos para futuros specs? |
| 2 | **Spotify priority** | ¿Implementar en esta fase o diferir a spec posterior? |
| 3 | **App Sandbox** | ¿Activar entitlements ahora o mantener desactivado para desarrollo? |