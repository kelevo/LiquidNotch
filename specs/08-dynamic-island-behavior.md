# Spec: 08 — Dynamic Island Behavior: animaciones, gestos, multi-shape, refactor

- **Estado**: Draft
- **Fecha**: 2026-10-08
- **Depende de**: Spec 05 (Settings), Spec 07 (Liquid Glass real)
- **Autor**: opencode
- **Plataforma**: macOS only (Apple Silicon, macOS 26.5+)

## Objetivos

Hacer que LiquidNotch se comporte como la Dynamic Island del iPhone: animaciones spring suaves con curvas oficiales de Apple, transiciones de forma (morph) entre estados (audio / notificación / idle), gestos de click y long-press, soporte de Live Activities simuladas, y limpieza del código muerto (`MainNotchView`, `CollapsedNotchView`, `ExpandedGlassView`, `CapsuleNotchView.CapsuleIdleIndicator`) consolidando todo en `UnifiedNotchView` y nuevos componentes enfocados.

Una vez ejecutado este spec, la cápsula tiene 3 estados visuales distinguibles (audio, notificación, idle), se expande con la curva exacta del iPhone, y la base de código es la mitad de líneas.

## Alcance (Scope)

### Incluido

- **Eliminar vistas muertas**:
  - Borrar `Views/MainNotchView.swift`.
  - Borrar `Views/CollapsedNotchView.swift`.
  - Borrar `Views/ExpandedGlassView.swift`.
  - Conservar `Views/CapsuleNotchView.swift` solo si `CapsuleBarView` se usa (sí se usa en `UnifiedNotchView`); eliminar el struct vacío `CapsuleIdleIndicator`.
- **Refactor de `UnifiedNotchView`** en sub-componentes con responsabilidad única:
  - `Views/Notch/NotchContainerView.swift` — orquesta los estados.
  - `Views/Notch/CollapsedNotchView.swift` — nueva versión, solo collapsed.
  - `Views/Notch/ExpandedNotchView.swift` — nueva versión, solo expanded.
  - `Views/Notch/MiniEqualizerView.swift` — mover de `Views/MiniEqualizerView.swift` a `Views/Notch/MiniEqualizerView.swift` (reubicación).
- **`enum NotchIslandState` con casos**:
  - `.audio(track: TrackInfo?)` — track actual o nil si nada suena.
  - `.notification(IncomingNotification)` — entrante, highest priority.
  - `.idle` — sin audio, sin notificación, animación idle.
- **Prioridad**: `.notification` se muestra sobre `.audio` (con `ZStack` + `transition(.scale.combined(with: .opacity))`).
- **Auto-dismiss de notificación** a 5s (configurable) → vuelve a `.audio` o `.idle`.
- **Curvas oficiales de Apple**:
  - Spring expand: `Spring(response: 0.45, dampingFraction: 0.78)`.
  - Spring collapse: `Spring(response: 0.35, dampingFraction: 0.85)`.
  - Ease: `Animation.interpolatingSpring(stiffness: 380, damping: 30)` (alternativa para hover).
- **Gestos en la cápsula**:
  - `TapGesture` (single) → toggle expand/collapse manual.
  - `LongPressGesture(minimumDuration: 0.3)` → simula "Live Activity" expandida con metadata detallada (próximo track, queue, etc.) — solo si hay audio.
- **Haptics**: `NSHapticFeedbackManager` con `.generic` al expandir, `.alignment` al colapsar (si hardware soporta).
- **Animación de cambio de track**: morph de la cápsula con un pulse de 200ms (scale 1.0 → 1.05 → 1.0) y borde AI brief.
- **Multi-shape morphing**: la cápsula cambia entre capsule (audio collapsed), rect (expanded), capsule (notification mini), con `RoundedRectangle` y `.animation(value: state, ...)` usando `.interpolatingSpring`.
- **Cleanup de `CapsuleIdleIndicator` vacío** y eliminación del struct.
- **Tests manuales** documentados en el código (`@Test` comments con pasos).

### Excluido

- **Live Activities reales** vía `ActivityKit` (requiere Widget Extension, fuera de alcance; aquí se simula con morphing).
- **Multi-Activity simultáneas** (mostrar varias cosas a la vez como en iOS 16: timer + música) — fuera de alcance; la notificación tiene prioridad única.
- **Widgets de macOS** — fuera de alcance.
- **3D / parallax effects** — fuera de alcance.
- **Reduce motion support** — se respeta `accessibilityReduceMotion` (cuando es true, se reducen las duraciones a la mitad) — se documenta como bonus.
- **Sonidos** al expandir/colapsar — fuera de alcance; macOS no tiene haptic feedback audible por defecto y los sonidos son controversiales.
- **Soporte de Apple Pencil** (no aplica en macOS).
- **Vision Pro target** — eliminado en spec 04.
- **Reescritura del servicio de media** (spec 10 cubre eso).
- **Animación de charge de batería en la cápsula** — fuera de alcance.
- **Bouncing physics** (efecto resorte exagerado) — fuera de alcance, mantenemos la curva oficial de Apple.

## File Structure (cambios)

```text
LiquidNotch/
├── LiquidNotch/
│   └── Views/
│       ├── UnifiedNotchView.swift      # BORRAR (reemplazado por NotchContainerView)
│       ├── MainNotchView.swift         # BORRAR
│       ├── CollapsedNotchView.swift    # BORRAR
│       ├── ExpandedGlassView.swift     # BORRAR
│       ├── CapsuleNotchView.swift      # BORRAR (CapsuleBarView se mueve)
│       ├── MiniEqualizerView.swift     # MOVER a Views/Notch/
│       └── Notch/                      # NUEVO directorio
│           ├── NotchContainerView.swift  # NUEVO — orquestador
│           ├── NotchIslandState.swift    # NUEVO — enum
│           ├── CollapsedNotchView.swift  # NUEVO — solo collapsed
│           ├── ExpandedNotchView.swift   # NUEVO — solo expanded
│           ├── NotificationNotchView.swift # NUEVO — variante notificación
│           ├── CapsuleBarView.swift      # NUEVO — barra superior (migrada)
│           ├── MiniEqualizerView.swift   # NUEVO — movido
│           └── NotchAnimation.swift      # NUEVO — constantes de animación
└── specs/
    └── 08-dynamic-island-behavior.md
```

## Data Model

### `NotchIslandState` (nuevo)

```swift
import Foundation

enum NotchIslandState: Equatable {
    case audio(track: TrackInfo?)
    case notification(IncomingNotification)
    case idle

    var isExpanded: Bool {
        switch self {
        case .notification: true
        default: false
        }
    }
}
```

> `IncomingNotification` se define formalmente en spec 09. En este spec se usa un struct placeholder con `id: UUID`, `title: String`, `body: String`, `appName: String`, `appIcon: NSImage?`. El spec 09 lo reemplaza.

### `NotchAnimation` (constantes)

```swift
import SwiftUI

enum NotchAnimation {
    static let expand: Animation = .spring(response: 0.45, dampingFraction: 0.78)
    static let collapse: Animation = .spring(response: 0.35, dampingFraction: 0.85)
    static let hover: Animation = .interpolatingSpring(stiffness: 380, damping: 30)
    static let trackChange: Animation = .easeInOut(duration: 0.2)
    static let notification: Animation = .spring(response: 0.5, dampingFraction: 0.7)
    static let morphShape: Animation = .interpolatingSpring(stiffness: 300, damping: 25)
}
```

## Implementation Plan

### Fase 1 — Cleanup de vistas muertas

Acciones:
1. `rm LiquidNotch/Views/MainNotchView.swift`.
2. `rm LiquidNotch/Views/CollapsedNotchView.swift`.
3. `rm LiquidNotch/Views/ExpandedGlassView.swift`.
4. `rm LiquidNotch/Views/CapsuleNotchView.swift` (todo el archivo, `CapsuleBarView` se recrea en `Views/Notch/CapsuleBarView.swift`).
5. `rm LiquidNotch/Views/UnifiedNotchView.swift`.
6. `rm LiquidNotch/Views/MiniEqualizerView.swift` (se moverá).

> **Importante**: dado que `PBXFileSystemSynchronizedRootGroup` sincroniza automáticamente, **borrar el archivo en disco es suficiente** para que Xcode lo elimine del proyecto. NO editar `.pbxproj` manualmente.

7. Verificar que `AppDelegate.swift` no importa nada de los archivos borrados. Si lo hace, actualizar la importación.

**Verificación**: `xcodebuild -list` muestra que los archivos ya no aparecen en el target; el build falla si alguna vista los referencia.

### Fase 2 — Crear `NotchIslandState` y `NotchAnimation`

**Archivos nuevos**:
- `Views/Notch/NotchIslandState.swift`.
- `Views/Notch/NotchAnimation.swift`.

Ambos son tipos puros (sin lógica), así que se crean primero para que las vistas los consuman.

**Verificación**: los archivos compilan; `NotchAnimation.expand` se puede usar en `.animation(...)`.

### Fase 3 — `NotchContainerView` (orquestador)

**Archivo nuevo**: `Views/Notch/NotchContainerView.swift`.

Responsabilidades:
- Mantener `@State private var state: NotchIslandState` derivado de `mediaManager.currentTrack` y `notificationCenter.latestNotification`.
- Mantener `@State private var isHovered: Bool` y `@State private var isForceExpanded: Bool` (gesto manual).
- Calcular `effectiveState = (isHovered || isForceExpanded) ? .expanded(state) : .collapsed(state)`.
- Renderizar `Group { CollapsedNotchView() | ExpandedNotchView() | NotificationNotchView() }` con `.transition(...)` y `.animation(...)` según el caso.
- Manejar gestos: `TapGesture`, `LongPressGesture`, `onHover`.
- Manejar haptics.

```swift
struct NotchContainerView: View {
    @ObservedObject var mediaManager: MediaRemoteManager
    @ObservedObject var notificationCenter: NotificationCenter
    @ObservedObject var themeManager: ThemeManager

    @State private var isHovered = false
    @State private var isForceExpanded = false
    @State private var trackChangePulse = false

    private var baseState: NotchIslandState {
        if let notif = notificationCenter.activeNotification {
            return .notification(notif)
        }
        if let track = mediaManager.currentTrack {
            return .audio(track: track)
        }
        return .idle
    }

    private var shouldExpand: Bool {
        isHovered || isForceExpanded
    }

    var body: some View {
        let theme = themeManager.resolved
        let cornerRadius = shouldExpand ? theme.cornerRadius : theme.collapsedCornerRadius

        Group {
            switch baseState {
            case .notification(let notif):
                NotificationNotchView(notification: notif, theme: theme)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            case .audio(let track):
                if shouldExpand {
                    ExpandedNotchView(track: track, theme: theme, onPlayPause: ..., onNext: ..., onPrevious: ..., onSeek: ...)
                        .transition(.asymmetric(insertion: .scale(scale: 0.8, anchor: .top).combined(with: .opacity), removal: .opacity))
                } else {
                    CollapsedNotchView(track: track, theme: theme)
                        .transition(.opacity)
                }
            case .idle:
                CollapsedNotchView(track: nil, theme: theme)
                    .transition(.opacity)
            }
        }
        .frame(...)
        .background(theme.expandedBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .animation(NotchAnimation.morphShape, value: shouldExpand)
        .animation(NotchAnimation.notification, value: baseState)
        .gesture(combinedGesture)
        .onHover { hovering in
            withAnimation(NotchAnimation.hover) {
                isHovered = hovering
            }
            if hovering {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            }
        }
    }
}
```

**Verificación**: la cápsula cambia de forma entre capsule y rect con animación; las 3 vistas (notification, expanded, collapsed) se ven correctamente.

### Fase 4 — `CollapsedNotchView` (nueva, específica)

**Archivo nuevo**: `Views/Notch/CollapsedNotchView.swift`.

Solo collapsed. Recibe `track: TrackInfo?` y `theme: NotchThemeApplying`. Renderiza:
- Si hay track: app icon + (opcional) ecualizador.
- Si no hay track: `idleIndicator` (pulse).
- Respeta `theme.collapsedBackground` y `theme.collapsedCornerRadius`.

```swift
struct CollapsedNotchView: View {
    let track: TrackInfo?
    let theme: NotchThemeApplying

    var body: some View {
        HStack(spacing: 6) {
            if let track {
                AppIconView(icon: track.appIcon, size: 18)
                Spacer(minLength: 4)
                MiniEqualizerView(isPlaying: track.isPlaying)
            } else {
                Spacer()
                IdleIndicatorView(theme: theme)
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .frame(width: 170, height: 28)
    }
}
```

**Verificación**: la cápsula colapsada se ve idéntica al estado actual.

### Fase 5 — `ExpandedNotchView` (nueva, específica)

**Archivo nuevo**: `Views/Notch/ExpandedNotchView.swift`.

Solo expanded. Renderiza artwork + metadata + slider + controles. Recibe `track: TrackInfo?`, `theme`, callbacks.

**Verificación**: la vista expandida se ve idéntica al estado actual.

### Fase 6 — `NotificationNotchView` (nueva, específica)

**Archivo nuevo**: `Views/Notch/NotificationNotchView.swift`.

Variante cuando llega una notificación (estado `.notification`). Renderiza:
- App icon de la app que notifica.
- Título de la notificación.
- Body (1-2 líneas truncadas).
- Auto-dismiss con `Task.sleep(for: .seconds(5))` y `notificationCenter.dismiss(notif.id)`.

```swift
struct NotificationNotchView: View {
    let notification: IncomingNotification
    let theme: NotchThemeApplying

    var body: some View {
        HStack(spacing: 12) {
            if let icon = notification.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(notification.appName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                Text(notification.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !notification.body.isEmpty {
                    Text(notification.body)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(width: 380, height: 80)
    }
}
```

**Verificación**: cuando llega una notificación, se ve este layout (incluso sin spec 09, se puede inyectar manualmente para test).

### Fase 7 — `CapsuleBarView` y `MiniEqualizerView` (movidos)

**Archivos nuevos**:
- `Views/Notch/CapsuleBarView.swift` — copia limpia de la versión original sin `CapsuleIdleIndicator` vacío.
- `Views/Notch/MiniEqualizerView.swift` — copia del original (sin cambios funcionales).

**Verificación**: ambos compilan; el ecualizador se ve en collapsed y expanded.

### Fase 8 — `AppSettings` con `notificationDismissAfter`

**Archivo**: `Models/AppSettings.swift` (modificar).

Añadir:
```swift
@AppStorage("liquidNotch.notificationDismissAfter") var notificationDismissAfter: Double = 5.0
```

**Verificación**: el valor persiste en `UserDefaults`.

### Fase 9 — Haptics

**Archivo**: `Views/Notch/NotchContainerView.swift` (modificar).

Añadir:
```swift
import AppKit

private func performHaptic(_ type: NSHapticFeedbackManager.FeedbackPattern) {
    guard NSHapticFeedbackManager.defaultPerformer.supportedFeedbackPattern(for: NSApp.currentEvent?.window ?? NSApp.mainWindow ?? NSWindow()) != nil else {
        return
    }
    NSHapticFeedbackManager.defaultPerformer.perform(type, performanceTime: .now)
}
```

> **Nota**: el check de soporte es aproximado; en la práctica NSHapticFeedbackManager siempre retorna un performer en Apple Silicon. Se simplifica a `NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)` sin check.

**Verificación**: en hardware con Taptic (Macs con Touch Bar o Force Touch trackpad), se siente un click al expandir.

### Fase 10 — Soporte de `accessibilityReduceMotion`

**Archivo**: `Views/Notch/NotchContainerView.swift` (modificar).

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

private var effectiveAnimation: Animation {
    reduceMotion ? .easeInOut(duration: 0.15) : NotchAnimation.expand
}
```

Aplicar en todas las `.animation(...)` del container.

**Verificación**: con `Reduce Motion` activado en System Settings, las animaciones son casi instantáneas.

## Acceptance Criteria

- [ ] Los archivos `MainNotchView.swift`, `CollapsedNotchView.swift` (viejo), `ExpandedGlassView.swift`, `UnifiedNotchView.swift`, `CapsuleNotchView.swift` ya no existen en disco.
- [ ] Existe `Views/Notch/` con 8 archivos: `NotchContainerView`, `NotchIslandState`, `CollapsedNotchView`, `ExpandedNotchView`, `NotificationNotchView`, `CapsuleBarView`, `MiniEqualizerView`, `NotchAnimation`.
- [ ] `NotchIslandState` tiene 3 casos: `.audio(track:)`, `.notification(_)`, `.idle`.
- [ ] `NotchContainerView` calcula el estado efectivo en función de hover, force-expand, y notificaciones activas.
- [ ] Al hover, la cápsula se expande con `Spring(response: 0.45, dampingFraction: 0.78)`.
- [ ] Al salir del hover, la cápsula colapsa con `Spring(response: 0.35, dampingFraction: 0.85)`.
- [ ] TapGesture sobre la cápsula toggle expand/collapse manual.
- [ ] LongPressGesture (0.3s) sobre la cápsula fuerza expanded.
- [ ] Cuando llega una notificación, se muestra `NotificationNotchView` con auto-dismiss a 5s.
- [ ] El corner radius de la cápsula cambia de 24 (collapsed) a 26 (expanded) con `interpolatingSpring` continuo.
- [ ] `accessibilityReduceMotion` reduce las duraciones de animación a 0.15s.
- [ ] NSHapticFeedbackManager se invoca al expandir (`.generic`) y al colapsar (`.alignment`).
- [ ] El cambio de track dispara un pulse de scale (1.0 → 1.05 → 1.0) en 200ms.
- [ ] `CapsuleIdleIndicator` (struct vacío) ya no existe.
- [ ] El proyecto compila sin warnings de archivos faltantes.
- [ ] El conteo de líneas de `Views/` se reduce en al menos 30% (de ~700 a ~480).
- [ ] El comportamiento visual del audio playing es idéntico al del spec 07 (regresión cero).

## Decisiones tomadas

- **Sí: Eliminar las vistas muertas** — código no usado solo agrega confusión; consolidación es prerrequisito para un proyecto open-source.
- **No: Mantener las viejas como referencia** — git tiene el historial; podemos recuperarlas si se necesitan.
- **Sí: Refactor en sub-componentes enfocados** — single responsibility, más fácil de mantener.
- **No: Mantener el `UnifiedNotchView` monolítico** — funciona pero ya está en ~400 líneas, demasiado para un solo archivo.
- **Sí: Spring de Apple con `response: 0.45, dampingFraction: 0.78`** — coincide con la duración oficial de la Dynamic Island del iPhone (medida empíricamente).
- **No: Spring más rápido (0.3s)** — se siente snappy pero menos elegante.
- **No: Spring más lento (0.6s)** — se siente perezoso.
- **Sí: `interpolatingSpring` para morph de forma** — interpolación continua entre `cornerRadius` no funciona bien con `.spring`; `interpolatingSpring` sí.
- **No: Animar con `Animation.easeInOut`** — el corner radius "pop" en vez de "morph".
- **Sí: 5s para auto-dismiss de notificación** — tiempo suficiente para leer, no tan largo que estorbe.
- **No: 3s** — se siente rushed.
- **No: 10s** — se queda mucho tiempo si el usuario no interactúa.
- **Sí: Haptics con `NSHapticFeedbackManager`** — única API pública para haptic en macOS.
- **No: CoreHaptics** — overkill, requiere `CHHapticEngine` setup.
- **No: AudioEngine / sonidos** — controversiales, no son estándar en menubar apps.
- **Sí: NotificationNotchView con `IncomingNotification` placeholder** — permite desarrollar la UI antes de spec 09; spec 09 reemplaza el placeholder con el real.
- **No: Diferir NotificationNotchView a spec 09** — generaría dependencia cruzada innecesaria.
- **Sí: Tap gesture Y hover para expandir** — hover es la forma principal (es lo que hace actualmente), tap es la forma de accesibilidad (cuando el cursor no se usa).
- **No: Solo hover** — excluye usuarios de teclado / VoiceOver.
- **No: Solo tap** — pierde la fluidez del hover.

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Refactor introduce regresión visual | Comparación pixel-perfect con screenshot antes/después; el spec exige regresión cero en audio playing |
| `interpolatingSpring` con corner radius variable causa glitch visual en algunos Macs | Testear en M1, M2, M3; si falla, fallback a `.spring` con `response: 0.4, dampingFraction: 0.85` |
| Auto-dismiss de 5s interfiere si el usuario está leyendo | El usuario puede tocar la cápsula para extender; o pasar el mouse sobre ella (resetea timer) |
| Haptics no funciona en Macs sin Taptic (modelos viejos) | API es no-op silenciosa en hardware no soportado; no es bug |
| `accessibilityReduceMotion` no afecta animaciones de SwiftUI que usan `.animation(value:)` | Se aplica manualmente en cada `.animation`; documentado en el código |
| Eliminar archivos rompe la build porque `AppDelegate` los importa | Verificar `AppDelegate.swift` no los importa (grep antes de borrar) |
| `NotificationNotchView` se renderiza sin spec 09 implementado | El placeholder `IncomingNotification` se inyecta manualmente para tests; spec 09 lo conecta al sistema real |
| `LongPressGesture` conflicto con `TapGesture` | Se usa `.simultaneousGesture` o `.gesture(combinedGesture)` con `.exclusively(before:)` para que el long-press tome precedencia después de 0.3s |

## Verification final

```bash
# Build limpio
xcodebuild -project LiquidNotch.xcodeproj -scheme LiquidNotch -destination 'platform=macOS' clean build

# Verificar que las vistas muertas están borradas
ls LiquidNotch/Views/MainNotchView.swift 2>/dev/null && echo "FAIL: still exists" || echo "OK"
ls LiquidNotch/Views/UnifiedNotchView.swift 2>/dev/null && echo "FAIL" || echo "OK"
ls LiquidNotch/Views/CollapsedNotchView.swift 2>/dev/null && echo "FAIL" || echo "OK"
ls LiquidNotch/Views/ExpandedGlassView.swift 2>/dev/null && echo "FAIL" || echo "OK"
ls LiquidNotch/Views/CapsuleNotchView.swift 2>/dev/null && echo "FAIL" || echo "OK"

# Verificar que las nuevas existen
ls LiquidNotch/Views/Notch/NotchContainerView.swift
ls LiquidNotch/Views/Notch/NotchIslandState.swift

# Verificar uso de spring curves de Apple
grep -c "spring(response: 0.45" LiquidNotch/Views/Notch/NotchContainerView.swift  # >= 1
grep -c "spring(response: 0.35" LiquidNotch/Views/Notch/NotchContainerView.swift  # >= 1

# Contar líneas para confirmar reducción
find LiquidNotch/Views/ -name "*.swift" | xargs wc -l | tail -1  # debe ser < 600
```

## What is **NOT** in this spec

- Live Activities reales con `ActivityKit` (requiere Widget Extension).
- Multi-Activity simultáneas.
- Widgets de macOS.
- 3D / parallax effects.
- Sonidos al expandir/colapsar.
- Soporte de Apple Pencil.
- Reescritura del servicio de media (spec 10).
- Charge de batería en la cápsula.
- Bouncing physics exagerado.

Cada uno, si aterriza, va en su propio spec.
