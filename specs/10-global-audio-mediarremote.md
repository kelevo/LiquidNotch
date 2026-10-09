# Spec: 10 — Audio Global con MediaRemote Privado (cualquier app del sistema)

- **Estado**: Draft
- **Fecha**: 2026-10-08
- **Depende de**: N/A (independiente)
- **Autor**: opencode
- **Plataforma**: macOS only (Apple Silicon, macOS 26.5+)

## Objetivos

Reemplazar el `MediaRemoteManager` actual (que solo detecta Apple Music y Spotify vía AppleScript) por un sistema que captura el "now playing" de **cualquier** app del sistema: navegadores (Chrome con YouTube/Spotify Web, Safari, Firefox, Arc, Brave), reproductores (VLC, IINA, MPV), juegos, apps de podcast, etc. La implementación usa el framework privado `MediaRemote.framework` (cargado vía `dlopen`) para llamar `MRMediaRemoteGetNowPlayingInfo` y `MRMediaRemoteRegisterForNowPlayingNotifications`. Como fallback, si el framework falla al cargar, se mantiene el soporte AppleScript para Apple Music y Spotify.

**Advertencia importante**: `MediaRemote.framework` es una API privada de Apple. Este spec es válido para un proyecto open-source en GitHub, pero **incompatible con la App Store** (la app será rechazada en review). Se documenta explícitamente en el README.

## Alcance (Scope)

### Incluido

- **`MediaRemoteBridge`** (`@MainActor` `ObservableObject`) que:
  - Carga `MediaRemote.framework` con `dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)`.
  - Declara con `dlsym` los símbolos necesarios: `MRMediaRemoteGetNowPlayingInfo`, `MRMediaRemoteRegisterForNowPlayingNotifications`, `MRMediaRemoteUnregisterForNowPlayingNotifications`, `MRMediaRemoteGetNowPlayingApplicationIsPlaying`, `MRMediaRemoteGetNowPlayingApplicationPlaybackState`.
  - Implementa `getNowPlayingInfo()` que retorna un diccionario `[String: Any]` con title, artist, album, duration, elapsedTime, artwork, bundleIdentifier, playbackRate, etc.
  - Implementa `sendCommand(_:)` con `MRMediaRemoteSendCommand` para play/pause/next/previous.
  - Implementa `registerForUpdates(callback:)` que invoca el callback cuando el sistema publica cambios en now playing.
- **`NowPlayingInfo`** struct con campos normalizados (title, artist, album, duration, elapsedTime, artwork, sourceBundleId, sourceAppName, sourceAppIcon, isPlaying).
- **Refactor de `MediaRemoteManager`**:
  - En vez de AppleScript, consume `MediaRemoteBridge.getNowPlayingInfo()` cada 1s (o según notification).
  - Si el bridge falla al cargar (Mac muy viejo o firma rota), fallback a AppleScript para Apple Music + Spotify como antes.
  - Las funciones `togglePlayPause`, `skipNext`, `skipPrevious`, `seek(to:)` se refactorizan para usar `MRMediaRemoteSendCommand` con el bundle ID del sender actual.
- **Timer de elapsed time**: se mantiene el `elapsedTimer` con 1s (spec 03), pero el "elapsed real" se obtiene también de `MRMediaRemoteGetNowPlayingInfo` para corregir drift.
- **UI**: el `source` en el `TrackInfo` se calcula desde el bundle identifier (no hardcoded). Bundle IDs comunes mapean a nombres legibles:
  - `com.apple.Music` → "Music"
  - `com.spotify.client` → "Spotify"
  - `com.google.Chrome` → "Chrome"
  - `com.apple.Safari` → "Safari"
  - `org.videolan.vlc` → "VLC"
  - `com.colliderli.iina` → "IINA"
  - otros → `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` para resolver, fallback al bundle ID raw.
- **Tests**: en Settings → About, añadir un botón "Diagnose MediaRemote" que muestra:
  - Si el framework se cargó (`dlopen` exitoso).
  - Si `getNowPlayingInfo` retorna datos.
  - Si las notificaciones están registradas.
- **Documentación en README** sobre la naturaleza privada del framework.

### Excluido

- **Captura del audio en sí** (waveform del audio playing) — fuera de alcance; `MediaRemote` da metadata, no samples. Para waveform real se necesitaría `CoreAudio` con un aggregate device virtual, lo cual es mucho más complejo.
- **Control universal de volumen del sistema** — fuera de alcance; `MediaRemote` no expone esto directamente (se puede con `CoreAudio` HAL, fuera de spec).
- **iOS / iPadOS** — eliminado en spec 04.
- **Historial de tracks** — solo el "now playing" actual.
- **Lyrics** — algunas apps exponen lyrics via MediaRemote, pero es inconsistente; fuera de alcance.
- **Equalizer control** (per-app EQ) — fuera de alcance.
- **AirPlay / multi-room** — fuera de alcance.
- **Picture-in-Picture** desde la cápsula — fuera de alcance.
- **Reproducir / pausar múltiples apps simultáneas** — solo la app "currently playing".
- **Modificación del sistema de audio** (cambiar sample rate, bit depth) — fuera de alcance.
- **Soporte para macOS < 26.5** — el target es 26.5, sin fallback a versiones viejas.

## File Structure (cambios)

```text
LiquidNotch/
├── LiquidNotch/
│   ├── Services/
│   │   ├── MediaRemoteBridge.swift     # NUEVO — wrapper de MediaRemote.framework
│   │   ├── MediaRemoteManager.swift    # MODIFICAR — consumir MediaRemoteBridge
│   │   ├── NowPlayingInfo.swift        # NUEVO — struct normalizado
│   │   └── ...
│   ├── Models/
│   │   └── TrackInfo.swift             # MODIFICAR — usar NowPlayingInfo internamente
│   └── Views/
│       └── Settings/
│           └── AboutSettingsView.swift # MODIFICAR — botón Diagnose MediaRemote
└── specs/
    └── 10-global-audio-mediarremote.md
```

## Data Model

### `NowPlayingInfo` (nuevo)

```swift
import AppKit
import Foundation

struct NowPlayingInfo: Equatable {
    let title: String
    let artist: String?
    let album: String?
    let duration: TimeInterval
    let elapsedTime: TimeInterval
    let playbackRate: Double
    let isPlaying: Bool
    let artworkData: Data?
    let sourceBundleId: String?
    let sourceAppName: String
    let sourceAppIcon: NSImage?

    static let empty = NowPlayingInfo(
        title: "", artist: nil, album: nil,
        duration: 0, elapsedTime: 0,
        playbackRate: 0, isPlaying: false,
        artworkData: nil, sourceBundleId: nil,
        sourceAppName: "Unknown", sourceAppIcon: nil
    )

    static func from(mediaRemoteDict: [String: Any]) -> NowPlayingInfo? {
        guard let title = mediaRemoteDict["kMRMediaRemoteNowPlayingInfoTitle"] as? String,
              !title.isEmpty else { return nil }

        let artist = mediaRemoteDict["kMRMediaRemoteNowPlayingInfoArtist"] as? String
        let album = mediaRemoteDict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String
        let duration = (mediaRemoteDict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double) ?? 0
        let elapsedTime = (mediaRemoteDict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double) ?? 0
        let playbackRate = (mediaRemoteDict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double) ?? 0
        let isPlaying = playbackRate > 0
        let artworkData = mediaRemoteDict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
        let bundleId = mediaRemoteDict["kMRMediaRemoteNowPlayingInfoApplicationIdentifier"] as? String
            ?? mediaRemoteDict["kMRMediaRemoteNowPlayingInfoClientProperties"] as? String
        let appName = bundleId.flatMap(resolveAppName) ?? "Unknown"
        let appIcon = bundleId.flatMap(resolveAppIcon)

        return NowPlayingInfo(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            elapsedTime: elapsedTime,
            playbackRate: playbackRate,
            isPlaying: isPlaying,
            artworkData: artworkData,
            sourceBundleId: bundleId,
            sourceAppName: appName,
            sourceAppIcon: appIcon
        )
    }

    private static let knownApps: [String: String] = [
        "com.apple.Music": "Music",
        "com.spotify.client": "Spotify",
        "com.google.Chrome": "Chrome",
        "com.apple.Safari": "Safari",
        "org.mozilla.firefox": "Firefox",
        "company.thebrowser.Browser": "Arc",
        "com.brave.Browser": "Brave",
        "org.videolan.vlc": "VLC",
        "com.colliderli.iina": "IINA",
        "io.mpv": "MPV"
    ]

    private static func resolveAppName(for bundleId: String) -> String {
        if let known = knownApps[bundleId] { return known }
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first,
           let name = app.localizedName {
            return name
        }
        return bundleId
    }

    private static func resolveAppIcon(for bundleId: String) -> NSImage? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first?.icon
    }
}
```

### `TrackInfo` actualizado

`TrackInfo` se mantiene (es la API que consume la UI), pero se inicializa desde `NowPlayingInfo` con un nuevo initializer:

```swift
extension TrackInfo {
    static func from(nowPlaying: NowPlayingInfo) -> TrackInfo {
        let artwork: NSImage? = nowPlaying.artworkData.flatMap { NSImage(data: $0) }
        let source = MediaSource.from(bundleId: nowPlaying.sourceBundleId)

        return TrackInfo(
            title: nowPlaying.title,
            artist: nowPlaying.artist ?? "Unknown Artist",
            album: nowPlaying.album,
            artworkImage: artwork,
            appIcon: nowPlaying.sourceAppIcon,
            duration: nowPlaying.duration,
            elapsedTime: nowPlaying.elapsedTime,
            isPlaying: nowPlaying.isPlaying,
            source: source
        )
    }
}
```

Y `MediaSource` se amplía con casos adicionales:

```swift
enum MediaSource: String, Equatable {
    case music = "Music"
    case spotify = "Spotify"
    case safari = "Safari"
    case chrome = "Chrome"
    case firefox = "Firefox"
    case arc = "Arc"
    case brave = "Brave"
    case vlc = "VLC"
    case iina = "IINA"
    case mpv = "MPV"
    case other = "Other"

    var iconSystemName: String {
        switch self {
        case .music, .spotify: "music.note"
        case .safari, .chrome, .firefox, .arc, .brave: "safari"
        case .vlc, .iina, .mpv: "play.rectangle"
        case .other: "app"
        }
    }

    static func from(bundleId: String?) -> MediaSource {
        guard let bundleId = bundleId else { return .other }
        switch bundleId {
        case "com.apple.Music": return .music
        case "com.spotify.client": return .spotify
        case "com.apple.Safari": return .safari
        case "com.google.Chrome": return .chrome
        case "org.mozilla.firefox": return .firefox
        case "company.thebrowser.Browser": return .arc
        case "com.brave.Browser": return .brave
        case "org.videolan.vlc": return .vlc
        case "com.colliderli.iina": return .iina
        case "io.mpv": return .mpv
        default: return .other
        }
    }
}
```

## Implementation Plan

### Fase 1 — `NowPlayingInfo`

**Archivo nuevo**: `Services/NowPlayingInfo.swift`.

Struct con campos normalizados. El método `from(mediaRemoteDict:)` parsea el diccionario que retorna `MRMediaRemoteGetNowPlayingInfo` (formato interno de Apple, keys con prefijo `kMRMediaRemote*`).

**Verificación**: el struct compila; `NowPlayingInfo.from([:])` retorna `nil`; `NowPlayingInfo.from([kMRMediaRemoteNowPlayingInfoTitle: "Test"])` retorna un struct válido.

### Fase 2 — `MediaRemoteBridge`

**Archivo nuevo**: `Services/MediaRemoteBridge.swift`.

Wrapper Swift del framework privado. Implementa:

```swift
import Foundation
import AppKit
import os

@MainActor
final class MediaRemoteBridge: ObservableObject {
    static let shared = MediaRemoteBridge()

    @Published private(set) var isAvailable: Bool = false
    @Published private(set) var lastError: String?

    private let logger = Logger(subsystem: "kelevo.LiquidNotch", category: "mediaremote")
    private var handle: UnsafeMutableRawPointer?
    private var updateCallback: ((NowPlayingInfo?) -> Void)?

    // C function signatures
    private typealias MRGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias MRRegisterFunction = @convention(c) (DispatchQueue, @escaping () -> Void) -> Void
    private typealias MRUnregisterFunction = @convention(c) (DispatchQueue) -> Void
    private typealias MRSendCommandFunction = @convention(c) (Int, NSDictionary?) -> Void

    private var getNowPlayingInfoFunc: MRGetNowPlayingInfoFunction?
    private var registerFunc: MRRegisterFunction?
    private var unregisterFunc: MRUnregisterFunction?
    private var sendCommandFunc: MRSendCommandFunction?

    private init() {
        loadFramework()
    }

    private func loadFramework() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let h = dlopen(path, RTLD_NOW) else {
            let err = String(cString: dlerror())
            logger.error("dlopen failed: \(err, privacy: .public)")
            lastError = "dlopen failed: \(err)"
            return
        }
        self.handle = h

        getNowPlayingInfoFunc = dlsym(h, "MRMediaRemoteGetNowPlayingInfo").map {
            unsafeBitCast($0, to: MRGetNowPlayingInfoFunction.self)
        }
        registerFunc = dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications").map {
            unsafeBitCast($0, to: MRRegisterFunction.self)
        }
        unregisterFunc = dlsym(h, "MRMediaRemoteUnregisterForNowPlayingNotifications").map {
            unsafeBitCast($0, to: MRUnregisterFunction.self)
        }
        sendCommandFunc = dlsym(h, "MRMediaRemoteSendCommand").map {
            unsafeBitCast($0, to: MRSendCommandFunction.self)
        }

        isAvailable = getNowPlayingInfoFunc != nil && sendCommandFunc != nil
        logger.info("MediaRemote framework loaded: \(self.isAvailable, privacy: .public)")
    }

    func getNowPlayingInfo(completion: @escaping (NowPlayingInfo?) -> Void) {
        guard let func = getNowPlayingInfoFunc else {
            completion(nil)
            return
        }
        func(DispatchQueue.main) { dict in
            let info = NowPlayingInfo.from(mediaRemoteDict: dict)
            completion(info)
        }
    }

    func registerForUpdates(callback: @escaping (NowPlayingInfo?) -> Void) {
        guard let func = registerFunc else { return }
        self.updateCallback = callback
        func(DispatchQueue.main) { [weak self] in
            self?.getNowPlayingInfo(completion: { info in
                self?.updateCallback?(info)
            })
        }
    }

    func unregisterForUpdates() {
        guard let func = unregisterFunc else { return }
        func(DispatchQueue.main)
        updateCallback = nil
    }

    enum Command: Int {
        case play = 0
        case pause = 1
        case togglePlayPause = 2
        case next = 4
        case previous = 5
    }

    func sendCommand(_ command: Command) {
        guard let func = sendCommandFunc else { return }
        func(command.rawValue, nil)
    }

    deinit {
        unregisterForUpdates()
        if let h = handle { dlclose(h) }
    }
}
```

**Verificación**: `MediaRemoteBridge.shared.isAvailable` es `true` en una Mac con MediaRemote funcional; `getNowPlayingInfo` retorna data cuando hay audio playing.

### Fase 3 — Refactor de `MediaRemoteManager`

**Archivo**: `Services/MediaRemoteManager.swift` (modificar).

Cambios principales:
1. Eliminar la dependencia de AppleScript (mantener como fallback si `MediaRemoteBridge.isAvailable == false`).
2. `startPolling()` se reemplaza por `bridge.registerForUpdates { info in ... }` (no polling, push real).
3. `fetchNowPlaying()` se reemplaza por `bridge.getNowPlayingInfo { ... }`.
4. `togglePlayPause`, `skipNext`, `skipPrevious` usan `bridge.sendCommand(.togglePlayPause)` etc. en lugar de AppleScript.
5. `seek(to:)` se mantiene con AppleScript porque MediaRemote no expone seek de forma estándar (se documenta).
6. El `MediaSource` ahora viene de `NowPlayingInfo.sourceBundleId`.
7. `artworkData` se decodifica a `NSImage` en `TrackInfo.from(nowPlaying:)`.

```swift
class MediaRemoteManager: ObservableObject {
    @Published var currentTrack: TrackInfo?
    @Published var useMediaRemote: Bool = false
    var isSeeking = false

    private let bridge = MediaRemoteBridge.shared
    private var elapsedTimer: Timer?
    private var seekDebounceTimer: Timer?
    private let workQueue = DispatchQueue(label: "com.liquidnotch.mediaremote", qos: .utility)
    private var artworkCache: [String: NSImage] = [:]
    private var fallbackManager: AppleScriptFallback?

    init() {
        if bridge.isAvailable {
            useMediaRemote = true
            bridge.registerForUpdates { [weak self] info in
                self?.updateFromNowPlaying(info)
            }
        } else {
            logger.warning("MediaRemote unavailable, falling back to AppleScript")
            fallbackManager = AppleScriptFallback()
            fallbackManager?.onUpdate = { [weak self] track in
                self?.currentTrack = track
            }
        }
    }

    private func updateFromNowPlaying(_ info: NowPlayingInfo?) {
        guard let info = info else {
            currentTrack = nil
            stopElapsedTimer()
            return
        }
        let track = TrackInfo.from(nowPlaying: info)
        if currentTrack != track {
            currentTrack = track
        }
        updateElapsedTimer()
    }

    func togglePlayPause() {
        if useMediaRemote {
            bridge.sendCommand(.togglePlayPause)
        } else {
            fallbackManager?.togglePlayPause()
        }
    }

    func skipNext() { bridge.sendCommand(.next) ?? fallbackManager?.skipNext() }
    func skipPrevious() { bridge.sendCommand(.previous) ?? fallbackManager?.skipPrevious() }
    // ... etc
}
```

> **Detalle**: `bridge.sendCommand` retorna `Void`; para combinar con fallback se usa optional chaining. Si bridge no está disponible, retorna nil y se usa fallback.

**Verificación**: al abrir YouTube en Chrome, `currentTrack` se actualiza con title del video, app icon de Chrome, etc.

### Fase 4 — `AppleScriptFallback`

**Archivo nuevo**: `Services/AppleScriptFallback.swift`.

Encapsula la lógica actual de AppleScript para Apple Music + Spotify. Es el path de fallback si `MediaRemote` no carga. La API es la misma que tenía el `MediaRemoteManager` viejo.

**Verificación**: en una Mac sin MediaRemote (improbable pero posible), la app sigue funcionando con Apple Music + Spotify.

### Fase 5 — `TrackInfo.from(nowPlaying:)`

**Archivo**: `Models/TrackInfo.swift` (modificar).

Añadir el initializer de extensión que crea un `TrackInfo` desde un `NowPlayingInfo`.

**Verificación**: el initializer compila; `TrackInfo.from(nowPlaying: NowPlayingInfo.empty)` retorna un track "vacío".

### Fase 6 — UI: `MediaSource` ya visible

**Archivos**: `Views/Notch/CapsuleBarView.swift` (spec 08), `Views/Notch/CollapsedNotchView.swift` (spec 08).

El `source` ya se muestra en el expanded view. Con este spec, ahora aparece "Chrome" / "Safari" / "VLC" / etc. en lugar de solo "Music" / "Spotify".

> **Mejora opcional**: añadir un icono de SF Symbol al lado del source name. `MediaSource.iconSystemName` ya lo provee.

**Verificación**: con YouTube playing en Chrome, la cápsula muestra "Chrome" (o el nombre resuelto) en el expanded.

### Fase 7 — `Diagnose MediaRemote` en `AboutSettingsView`

**Archivo**: `Views/Settings/AboutSettingsView.swift` (modificar).

Añadir un botón "Diagnose MediaRemote" que muestra un sheet con:
- `MediaRemote loaded`: `Yes` / `No` (con `dlerror()` si falló).
- `Get now playing`: el JSON retornado por `MRMediaRemoteGetNowPlayingInfo` (formateado).
- `Registered for updates`: `Yes` / `No`.
- `Last error`: si hubo.

```swift
struct MediaRemoteDiagnosticsView: View {
    @ObservedObject var bridge = MediaRemoteBridge.shared
    @State private var nowPlayingDict: String = "Loading..."

    var body: some View {
        Form {
            LabeledContent("Framework loaded", value: bridge.isAvailable ? "Yes" : "No")
            LabeledContent("Last error", value: bridge.lastError ?? "None")
            Button("Refresh now playing") {
                bridge.getNowPlayingInfo { info in
                    nowPlayingDict = info.map { String(describing: $0) } ?? "nil"
                }
            }
            Text(nowPlayingDict)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding()
        .frame(width: 480, height: 320)
    }
}
```

**Verificación**: el diagnóstico muestra correctamente si el framework cargó.

### Fase 8 — Documentación en README

**Archivo**: `README.md` (modificar, creado en spec 04).

Añadir sección "About MediaRemote framework" explicando:
- Es una API privada de Apple.
- Permite capturar el "now playing" de cualquier app del sistema.
- Incompatible con la App Store.
- Si Apple cambia la API en una versión futura, hay que actualizar `MediaRemoteBridge`.
- En el peor caso, el fallback AppleScript sigue funcionando con Apple Music + Spotify.

**Verificación**: la sección está en el README.

## Acceptance Criteria

- [ ] Existe `Services/MediaRemoteBridge.swift` con `dlopen`, `dlsym`, y wrappers Swift.
- [ ] Existe `Services/NowPlayingInfo.swift` con struct normalizado y `from(mediaRemoteDict:)`.
- [ ] Existe `Services/AppleScriptFallback.swift` con la lógica de AppleScript extraída.
- [ ] `MediaRemoteBridge.shared.isAvailable` retorna `true` en una Mac con MediaRemote funcional.
- [ ] Al abrir YouTube en Chrome y reproducir un video, `currentTrack` se actualiza con title del video, app icon de Chrome, source = "Chrome", elapsed time, duration.
- [ ] Al abrir Safari con un video de Vimeo, similar a Chrome.
- [ ] Al abrir VLC con un video local, similar.
- [ ] `togglePlayPause` pausa/reanuda el video de YouTube en Chrome.
- [ ] `skipNext` salta al siguiente video en una playlist de YouTube.
- [ ] El timer de elapsed time actualiza cada 1s con drift mínimo.
- [ ] Si `MediaRemoteBridge.isAvailable == false`, el fallback AppleScript funciona para Apple Music + Spotify.
- [ ] El log muestra "MediaRemote framework loaded: true" en arranque normal.
- [ ] La sección "Diagnose MediaRemote" en Settings → About muestra el estado real del framework.
- [ ] El README tiene una sección explicando la naturaleza privada del framework.
- [ ] El proyecto compila sin warnings de Sendable, @MainActor violations, o leaks de `UnsafeMutableRawPointer`.
- [ ] El bundle de la app no contiene `MediaRemote.framework` (se carga dinámicamente).
- [ ] La firma ad-hoc del proyecto no requiere entitlements especiales (MediaRemote es loaded sin entitlement).

## Decisiones tomadas

- **Sí: `dlopen` + `dlsym`** — única forma de usar una API privada sin entitlements.
- **No: Bridge Swift con `@_silgen_name`** — `@_silgen_name` requiere enlazar estáticamente, lo cual el linker rechaza para frameworks privados.
- **No: Bridging header con `MediaRemote.framework` agregado al target** — Xcode no permite agregar frameworks privados; serían errores de build.
- **Sí: Push notifications en vez de polling** — `MRMediaRemoteRegisterForNowPlayingNotifications` notifica instantáneamente cuando cambia el now playing. Polling sería innecesario y wasteful.
- **No: Polling cada 1s** — funciona pero consume CPU.
- **Sí: Fallback AppleScript solo para Apple Music + Spotify** — son las apps que AppleScript expone de forma estable.
- **No: Fallback para todas las apps via AppleScript** — AppleScript para Chrome/Safari es muy frágil, no vale la pena.
- **Sí: `MediaSource` enum con casos específicos** — permite a la UI mostrar iconos diferentes por source.
- **No: `MediaSource = String` libre** — pierde type safety.
- **Sí: `NowPlayingInfo` struct separado de `TrackInfo`** — `NowPlayingInfo` es la representación del dato del sistema; `TrackInfo` es la representación para la UI. Separación clara.
- **No: Reemplazar `TrackInfo` directamente** — cambios rompen la UI actual.
- **Sí: Singleton `MediaRemoteBridge.shared`** — solo debe haber un wrapper del framework en toda la app.
- **No: Instancia por uso** — múltiples `dlopen` del mismo framework es ineficiente.
- **Sí: `unsafeBitCast` para C function pointers** — estándar de Swift para interoperabilidad con C.
- **No: Crear un `import MediaRemote` real** — el framework no es público, esto fallaría en compilación.
- **Sí: Documentar en README que es API privada** — transparency para usuarios y contribuidores.
- **No: Ocultar el hecho** — la app sería insostenible a largo plazo si la API cambia.
- **Sí: `MRMediaRemoteSendCommand` con `bundleId` como `nil`** — el sistema rutea el comando al app que está actualmente playing; no necesitamos saber cuál es.
- **No: Specular el bundle ID** — innecesario.

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Apple cambia las keys de `MRMediaRemoteNowPlayingInfo*` en una versión futura de macOS | El código está aislado en `NowPlayingInfo.from(mediaRemoteDict:)`; un cambio de key se arregla en un solo lugar |
| Apple cambia la firma de `MRMediaRemoteSendCommand` (ej. requiere `bundleId` no-nil) | `MediaRemoteBridge.sendCommand` es el único punto de contacto; se ajusta sin tocar la UI |
| `dlopen` falla por cambios en la path del framework | Constante string en una sola línea; fácil de corregir si Apple lo mueve |
| Cargar `MediaRemote.framework` causa crash en macOS sin esa versión | La app detecta `isAvailable == false` y cae al fallback AppleScript sin crash |
| `unsafeBitCast` viola Sendable y causa warnings de concurrencia | El bridge es `@MainActor`; el callback se dispatcha explícitamente a main |
| `MediaRemote.framework` se marca como deprecated o removido | El fallback AppleScript sigue funcionando con Apple Music + Spotify (el 80% de usuarios); se documenta |
| Apps que usan DRM (Apple TV+, Netflix en Safari) bloquean el artwork en MediaRemote | El campo `artworkData` retorna `nil`; la UI cae al SF Symbol fallback |
| La app es rechazada en App Store review (por API privada) | Documentado en README; el proyecto es open-source, no se distribuye vía App Store |
| Memoria: `handle` no se libera en `deinit` si la app se cierra abruptamente | `dlclose` en `deinit`; si la app crashea, el kernel libera el handle |
| `MRMediaRemoteGetNowPlayingInfo` retorna un dictionary que requiere casting cuidadoso a `[String: Any]` | El cast está validado con `as?` en cada campo; defaults seguros |
| `MediaRemote` requiere que la app esté firmada con un team identifier válido | En desarrollo (sin firma), puede funcionar con firma ad-hoc; en producción con Developer ID, funciona |

## Verification final

```bash
# Build limpio
xcodebuild -project LiquidNotch.xcodeproj -scheme LiquidNotch -destination 'platform=macOS' clean build

# Verificar archivos
ls LiquidNotch/Services/MediaRemoteBridge.swift
ls LiquidNotch/Services/NowPlayingInfo.swift
ls LiquidNotch/Services/AppleScriptFallback.swift

# Verificar uso de dlopen / dlsym
grep -c "dlopen" LiquidNotch/Services/MediaRemoteBridge.swift  # >= 1
grep -c "dlsym" LiquidNotch/Services/MediaRemoteBridge.swift   # >= 3

# Verificar que NO hay import de MediaRemote real
grep -c "import MediaRemote" LiquidNotch/ -r  # 0

# Verificar log al arrancar
log show --predicate 'subsystem == "kelevo.LiquidNotch" AND category == "mediaremote"' --last 1m
# debe contener "MediaRemote framework loaded: true"

# Test manual: abrir YouTube en Chrome, ver la cápsula actualizarse
# (no automatizable; documentado en README como manual test)
```

## What is **NOT** in this spec

- Captura del audio en sí (waveform).
- Control universal de volumen.
- iOS / iPadOS.
- Historial de tracks.
- Lyrics.
- Equalizer control.
- AirPlay / multi-room.
- Picture-in-Picture.
- Reproducir / pausar múltiples apps simultáneas.
- Modificación del sistema de audio.
- Soporte para macOS < 26.5.

Cada uno, si aterriza, va en su propio spec.
