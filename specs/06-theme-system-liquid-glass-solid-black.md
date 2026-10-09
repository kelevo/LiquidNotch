# Spec: 06 — Sistema de Temas: Liquid Glass y Solid Black

- **Estado**: Draft
- **Fecha**: 2026-10-08
- **Depende de**: Spec 05 (Settings panel)
- **Autor**: opencode
- **Plataforma**: macOS only (Apple Silicon)

## Objetivos

Añadir un sistema de temas con dos opciones seleccionables desde Settings: **Liquid Glass** (efecto translúcido con blur, gradient Apple Intelligence animado) y **Solid Black** (fondo negro sólido estilo iPhone Dynamic Island clásico, sin glass). La selección persiste entre sesiones, se aplica en caliente con un cross-fade suave, y queda disponible como `enum NotchTheme` para que las vistas consulten qué estilo usar.

## Alcance (Scope)

### Incluido

- `enum NotchTheme` (ya declarado como placeholder en spec 05) con casos `.liquidGlass` y `.solidBlack`.
- `ThemeManager` (`ObservableObject`) que envuelve `AppSettings.theme` y expone un `@Published var current: NotchTheme` que se actualiza con animación.
- Protocolo `NotchThemeApplying` con propiedades requeridas para vistas: `cornerRadius`, `collapsedCornerRadius`, `idleGradientOpacity`, `expandedBackgroundLayers`, `borderStyle`, `idlePulseStyle`, `idleIndicatorStyle`.
- Implementación concreta `LiquidGlassTheme: NotchThemeApplying` que devuelve la configuración actual (translúcido, AI gradient, animated orbits).
- Implementación concreta `SolidBlackTheme: NotchThemeApplying` que devuelve configuración minimalista (negro puro, sin AI gradient, sin animación de fondo, opcional borde fino).
- Refactor de `UnifiedNotchView` para consumir `ThemeManager` en vez de tener valores hardcodeados.
- UI en `ThemeSettingsView` (Settings → Theme) con un `Picker` (segmented) o lista de cards con preview.
- Animación cross-fade de 0.4s al cambiar el tema.
- Persistencia en `UserDefaults` bajo key `liquidNotch.theme` (ya existe en spec 05).
- Reset al cambiar tema no requiere reinicio de la app.

### Excluido

- **Editor de temas personalizados** (color pickers, save/load) — fuera de alcance.
- **Más de 2 temas** (un spec futuro podría añadir "Dynamic Island" estilo iOS 16, "Monochrome", etc.) — se deja `enum` extensible con `CaseIterable`.
- **Temas por app de origen** (ej. Spotify siempre usa tema "Spotify") — fuera de alcance.
- **Schedule automático por hora del día** (claro/oscuro) — fuera de alcance; macOS ya tiene dark mode.
- **Sincronización vía iCloud** — fuera de alcance.
- **Preview en vivo en la cápsula** sin abrir Settings — fuera de alcance; el cambio se ve al abrir expanded o pasar el mouse.

## File Structure (cambios)

```text
LiquidNotch/
├── LiquidNotch/
│   ├── Models/
│   │   ├── AppSettings.swift           # existente — añadir @AppStorage "liquidNotch.theme" (ya está)
│   │   ├── NotchTheme.swift            # MODIFICAR — añadir conformidad a Identifiable, CaseIterable y helpers
│   │   └── TrackInfo.swift             # existente
│   ├── Services/
│   │   └── ThemeManager.swift          # NUEVO — ObservableObject wrapper
│   ├── Themes/
│   │   ├── NotchThemeApplying.swift    # NUEVO — protocolo
│   │   ├── LiquidGlassTheme.swift      # NUEVO — valores actuales
│   │   ├── SolidBlackTheme.swift       # NUEVO — valores minimalistas
│   │   └── ThemePalette.swift          # NUEVO — colores y constantes compartidas
│   └── Views/
│       ├── Settings/
│       │   └── ThemeSettingsView.swift # MODIFICAR — picker funcional
│       └── UnifiedNotchView.swift      # MODIFICAR — consumir ThemeManager
└── specs/
    └── 06-theme-system-liquid-glass-solid-black.md  # este spec
```

## Data Model

### `NotchTheme` (ampliado de spec 05)

```swift
import Foundation
import SwiftUI

enum NotchTheme: String, CaseIterable, Identifiable, Codable {
    case liquidGlass = "liquidGlass"
    case solidBlack = "solidBlack"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .liquidGlass: "Liquid Glass"
        case .solidBlack:  "Solid Black"
        }
    }

    var iconName: String {
        switch self {
        case .liquidGlass: "drop.fill"
        case .solidBlack:  "circle.fill"
        }
    }

    var description: String {
        switch self {
        case .liquidGlass: "Translucent glass with animated Apple Intelligence gradient"
        case .solidBlack:  "Solid black background, classic iPhone Dynamic Island look"
        }
    }
}
```

### `NotchThemeApplying` (protocolo)

```swift
import SwiftUI

protocol NotchThemeApplying {
    var id: NotchTheme { get }
    var cornerRadius: CGFloat { get }              // expanded (e.g. 26)
    var collapsedCornerRadius: CGFloat { get }     // collapsed (e.g. 12 or 24)
    var idleGradientEnabled: Bool { get }          // AI gradient orbits visible?
    var idleGradientOpacity: Double { get }        // max opacity when active
    var idleIndicatorEnabled: Bool { get }         // pulse dot when no audio
    var idlePulseDuration: Double { get }          // seconds
    var collapsedBackground: AnyView { get }       // base fill (Color.black, etc.)
    var expandedBackground: AnyView { get }        // base fill + material
    var borderWidth: CGFloat { get }               // 0.5 / 0.0
    var borderOpacity: Double { get }              // 0.12 / 0.0
    var transitionDuration: Double { get }         // cross-fade on theme change
}
```

### `ThemePalette` (constantes compartidas)

```swift
import SwiftUI

enum ThemePalette {
    static let aiColors: [Color] = [
        Color(red: 0.945, green: 0.608, blue: 0.200),  // naranja
        Color(red: 0.976, green: 0.208, blue: 0.384),  // rosa
        Color(red: 0.200, green: 0.667, blue: 0.902),  // azul
        Color(red: 0.863, green: 0.514, blue: 0.933)   // púrpura
    ]

    static let baseBlack = Color.black
    static let glassWhite = Color.white.opacity(0.08)
    static let glassBorderOpacity = 0.12
}
```

### `ThemeManager`

```swift
import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    @Published var current: NotchTheme
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
        self.current = settings.theme
    }

    func apply(_ theme: NotchTheme, animated: Bool = true) {
        guard theme != current else { return }
        if animated {
            withAnimation(.easeInOut(duration: 0.4)) {
                current = theme
            }
        } else {
            current = theme
        }
        settings.theme = theme
    }

    var resolved: NotchThemeApplying {
        switch current {
        case .liquidGlass: LiquidGlassTheme()
        case .solidBlack:  SolidBlackTheme()
        }
    }
}
```

### `LiquidGlassTheme`

```swift
import SwiftUI

struct LiquidGlassTheme: NotchThemeApplying {
    let id: NotchTheme = .liquidGlass
    let cornerRadius: CGFloat = 26
    let collapsedCornerRadius: CGFloat = 24
    let idleGradientEnabled = true
    let idleGradientOpacity: Double = 0.5
    let idleIndicatorEnabled = true
    let idlePulseDuration: Double = 0.6
    let borderWidth: CGFloat = 0.5
    let borderOpacity: Double = 0.12
    let transitionDuration: Double = 0.4

    var collapsedBackground: AnyView {
        AnyView(
            ZStack {
                Capsule().fill(ThemePalette.baseBlack)
                Capsule().fill(
                    LinearGradient(
                        colors: ThemePalette.aiColors.map { $0.opacity(0.6) },
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            }
        )
    }

    var expandedBackground: AnyView {
        AnyView(
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(ThemePalette.baseBlack.opacity(0.15))
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(ThemePalette.glassWhite)
            }
        )
    }
}
```

### `SolidBlackTheme`

```swift
import SwiftUI

struct SolidBlackTheme: NotchThemeApplying {
    let id: NotchTheme = .solidBlack
    let cornerRadius: CGFloat = 26
    let collapsedCornerRadius: CGFloat = 24
    let idleGradientEnabled = false
    let idleGradientOpacity: Double = 0.0
    let idleIndicatorEnabled = true
    let idlePulseDuration: Double = 0.8
    let borderWidth: CGFloat = 0.0
    let borderOpacity: Double = 0.0
    let transitionDuration: Double = 0.4

    var collapsedBackground: AnyView {
        AnyView(Capsule().fill(ThemePalette.baseBlack))
    }

    var expandedBackground: AnyView {
        AnyView(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(ThemePalette.baseBlack)
        )
    }
}
```

## Implementation Plan

### Fase 1 — `NotchTheme` ampliado

**Archivo**: `Models/NotchTheme.swift` (modificar).

Reemplazar el placeholder del spec 05 con la versión completa de arriba (iconName, description, Codable). Mantener compatibilidad con la key `liquidGlass` en UserDefaults.

**Verificación**: el proyecto sigue compilando; `NotchTheme.allCases` retorna 2 elementos.

### Fase 2 — `ThemePalette`

**Archivo nuevo**: `Themes/ThemePalette.swift`.

Centraliza los colores AI y las constantes compartidas para que `LiquidGlassTheme` y `SolidBlackTheme` (y futuras vistas) los usen sin duplicar.

**Verificación**: el archivo compila; `ThemePalette.aiColors` retorna 4 colores.

### Fase 3 — Protocolo `NotchThemeApplying`

**Archivo nuevo**: `Themes/NotchThemeApplying.swift`.

Protocolo con las propiedades de arriba. `AnyView` se usa para los backgrounds porque cambian estructuralmente entre temas (LinearGradient con 4 colores vs. Color plano); el costo de AnyView aquí es despreciable (1 switch por rebuild de tema).

**Verificación**: el protocolo compila; los structs que lo implementan satisfacen el conformance sin warnings.

### Fase 4 — `LiquidGlassTheme` y `SolidBlackTheme`

**Archivos nuevos**: `Themes/LiquidGlassTheme.swift`, `Themes/SolidBlackTheme.swift`.

Implementaciones concretas según los snippets de arriba. Los valores hardcodeados que estaban en `UnifiedNotchView.swift` (cornerRadius, colores, opacidades) se mueven aquí.

> **Decisión documentada**: el tema Liquid Glass mantiene el comportamiento actual idéntico; el spec 07 ("Liquid Glass real con `glassEffect`") reemplaza el `Material` casero por la API real de Apple sin tocar este archivo.

**Verificación**: el proyecto compila; `ThemeManager.resolved` retorna la implementación correcta según `current`.

### Fase 5 — `ThemeManager`

**Archivo nuevo**: `Services/ThemeManager.swift`.

`@MainActor ObservableObject` que envuelve `AppSettings.theme`. El método `apply(_:animated:)` actualiza con animación (o sin ella, para tests) y persiste.

**Inyección**:
- `@StateObject private var themeManager: ThemeManager` en `LiquidNotchApp` (inicializado con `settings: AppSettings`).
- Pasar al `AppDelegate` igual que `AppSettings`.
- `UnifiedNotchView` lo recibe como `@ObservedObject` desde el `AppDelegate` o como `@EnvironmentObject` desde el `LiquidNotchApp`.

**Verificación**: cambiar `themeManager.current` en código actualiza las vistas; cerrar y reabrir la app restaura el tema.

### Fase 6 — Refactor de `UnifiedNotchView`

**Archivo**: `Views/UnifiedNotchView.swift` (modificar).

Cambios:
1. Reemplazar las constantes hardcodeadas (cornerRadius, opacidades, colores) por `themeManager.resolved`.
2. Reemplazar el `ZStack` con `LinearGradient` de AI colors en el background colapsado por `themeManager.resolved.collapsedBackground`.
3. Reemplazar el `ZStack` del background expandido por `themeManager.resolved.expandedBackground`.
4. Si `themeManager.resolved.idleGradientEnabled == false`, eliminar el `Canvas` de AI orbits.
5. Si `themeManager.resolved.idleIndicatorEnabled == false`, eliminar el `CapsuleIdleIndicator`.
6. Aplicar `themeManager.resolved.cornerRadius` y `themeManager.resolved.collapsedCornerRadius` al `clipShape`.
7. Borde: `RoundedRectangle.strokeBorder` con opacidad y width del theme.
8. Animar el cambio de tema con `withAnimation(.easeInOut(duration: 0.4))` envuelto en `.onChange(of: themeManager.current)`.

**Verificación**: cambiar entre temas en Settings actualiza la cápsula en tiempo real con cross-fade.

### Fase 7 — `ThemeSettingsView`

**Archivo**: `Views/Settings/ThemeSettingsView.swift` (modificar placeholder de spec 05).

Layout: lista vertical con dos `ThemeCard` rows, cada una con:
- Icono (`Image(systemName: theme.iconName)` con tinte del color del tema).
- Título (`Text(theme.displayName)`).
- Descripción (`Text(theme.description)` con color secundario).
- Indicador de selección (`Image(systemName: "checkmark")` si está activo).
- `.background` y `.onTapGesture` que llama `themeManager.apply(theme)`.

```swift
struct ThemeSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.headline)

            ForEach(NotchTheme.allCases) { theme in
                ThemeCard(
                    theme: theme,
                    isSelected: themeManager.current == theme,
                    onSelect: { themeManager.apply(theme) }
                )
            }
        }
        .padding()
    }
}

struct ThemeCard: View {
    let theme: NotchTheme
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: theme.iconName)
                .font(.system(size: 22))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme == .liquidGlass ? .blue : .black)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(theme.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Text(theme.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.accentColor)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(isSelected ? 0.4 : 0.0))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}
```

**Verificación**: las dos cards se ven; seleccionar cada una aplica el tema y muestra el checkmark.

## Acceptance Criteria

- [ ] `enum NotchTheme` tiene 2 casos (`liquidGlass`, `solidBlack`) y conformidad a `CaseIterable`, `Identifiable`, `Codable`.
- [ ] `ThemePalette.aiColors` retorna exactamente 4 colores.
- [ ] `LiquidGlassTheme` y `SolidBlackTheme` implementan `NotchThemeApplying` sin warnings.
- [ ] `ThemeManager` es `@MainActor ObservableObject` y persiste cambios en `AppSettings`.
- [ ] `UnifiedNotchView` no contiene valores hardcodeados de colores de tema (excepto constantes AI palette que ahora viven en `ThemePalette`).
- [ ] En Settings → Theme, las dos cards se ven con icono, título, descripción.
- [ ] Seleccionar "Liquid Glass" aplica el tema translúcido con AI gradient visible.
- [ ] Seleccionar "Solid Black" aplica el tema negro sólido sin AI gradient.
- [ ] El cambio de tema se ve en la cápsula en tiempo real con cross-fade de 0.4s.
- [ ] El tema seleccionado persiste tras cerrar y reabrir la app.
- [ ] `defaults read kelevo.LiquidNotch liquidNotch.theme` retorna `liquidGlass` o `solidBlack`.
- [ ] El tema Solid Black NO muestra las órbitas AI animadas en ningún estado.
- [ ] El tema Solid Black NO muestra el gradient AI en el background de la cápsula colapsada.
- [ ] El tema Solid Black usa `Color.black` puro como fill (sin tinte blanco, sin material).
- [ ] El tema Liquid Glass mantiene el comportamiento visual idéntico al actual (regresión cero).

## Decisiones tomadas

- **Sí: Protocolo `NotchThemeApplying` con `AnyView` para backgrounds** — los backgrounds tienen estructura muy distinta entre temas; un protocolo con `View` genérico añade complejidad sin beneficio.
- **No: Tema como un solo struct gigante con flags** — campos sin usar según el tema, propenso a errores.
- **Sí: `ThemeManager` separado de `AppSettings`** — el manager maneja la lógica de UI (animaciones, estado `@Published`); `AppSettings` solo persiste. Separación clara de responsabilidades.
- **No: `AppSettings` directamente como `ObservableObject` de UI** — `@AppStorage` ya emite cambios, pero no controla la animación de transición.
- **Sí: Cross-fade de 0.4s** — duración que se siente como Apple; coincide con las transiciones nativas de macOS.
- **No: Cross-fade instantáneo** — visualmente brusco; malo para UX.
- **No: Cross-fade de 1.0s** — se siente lento al cambiar entre opciones.
- **Sí: `iconName` y `description` en `NotchTheme`** — usados en `ThemeCard`; tenerlos en el enum evita un switch externo.
- **Sí: `Codable` en `NotchTheme`** — habilita serialización futura (iCloud sync, export de config) sin breaking change.
- **No: `Codable` solo cuando se necesite** — añadir conformidad ahora es gratis (rawValue ya es String).
- **Sí: `collapsedCornerRadius = 24` en Solid Black** (más redondo que Liquid Glass que usa 12) — da un look más orgánico estilo iPhone Dynamic Island que es 100% circular.
- **No: Mismo `cornerRadius` en ambos temas** — el tema Solid Black pide visual más limpio; Liquid Glass pide más cuadrado para mostrar el gradient.

## Riesgos

| Riesgo | Mitigación |
|---|---|
| `AnyView` en backgrounds causa recompilaciones innecesarias | Solo se cambia el `AnyView` al cambiar de tema (raro); dentro de un tema, SwiftUI no recompila |
| Refactor de `UnifiedNotchView` introduce regresión visual en Liquid Glass | Diff side-by-side con screenshot antes/después; el spec exige regresión cero |
| Cross-fade a 0.4s se siente lento en interacciones rápidas (ej. demo) | Configurable vía `@AppStorage("liquidNotch.theme.transitionDuration")` en un spec futuro si se pide |
| `ThemeManager` y `AppSettings` duplican estado del tema | `ThemeManager.apply` es la única vía de escritura; `AppSettings.theme` es read-only desde fuera |
| El placeholder de `ThemeSettingsView` del spec 05 ya tenía texto "Coming soon" | Se reemplaza en este spec; el placeholder nunca llegó a producción |
| `SolidBlackTheme` con `idleIndicatorEnabled = true` sigue mostrando el pulse indicator | Decisión intencional: indica que la app está "viva" aunque no haya audio; al gusto del usuario |

## Verification final

```bash
# Build limpio
xcodebuild -project LiquidNotch.xcodeproj -scheme LiquidNotch -destination 'platform=macOS' clean build

# Verificar enum tiene 2 casos
grep -c "case liquidGlass" LiquidNotch/Models/NotchTheme.swift  # >= 1
grep -c "case solidBlack"  LiquidNotch/Models/NotchTheme.swift  # >= 1

# Verificar que los AI colors ya no están hardcodeados en UnifiedNotchView
grep -c "0.945, green: 0.608" LiquidNotch/Views/UnifiedNotchView.swift  # debe imprimir 0

# Verificar que el tema persiste
defaults read kelevo.LiquidNotch liquidNotch.theme  # "liquidGlass" o "solidBlack"
```

## What is **NOT** in this spec

- Editor visual de temas personalizados.
- Más de 2 temas (un spec futuro podría añadir "Dynamic Island" estilo iOS 16, "Monochrome", etc.).
- Temas por app de origen.
- Schedule automático (claro/oscuro) por hora.
- Sincronización iCloud.
- Preview en vivo en la cápsula sin abrir Settings.

Cada uno, si aterriza, va en su propio spec.
