# Spec: 07 — Migración a la API real de Liquid Glass (glassEffect + GlassEffectContainer)

- **Estado**: Draft
- **Fecha**: 2026-10-08
- **Depende de**: Spec 06 (sistema de temas)
- **Autor**: opencode
- **Plataforma**: macOS only (Apple Silicon, macOS 26.5+)

## Objetivos

Reemplazar la implementación casera de "Liquid Glass" (basada en `.ultraThinMaterial`, `LinearGradient` y un `Canvas` con blur) por la API oficial de Apple introducida en macOS 26 / iOS 26: `glassEffect(_:in:)`, `GlassEffectContainer { }`, y `Glass.regular.interactive()`. El tema Solid Black no usa glass y queda intacto. La migración se hace solo cuando el tema activo es Liquid Glass, manteniendo regresión cero en comportamiento.

## Alcance (Scope)

### Incluido

- Reemplazar `.fill(.ultraThinMaterial)` en el background expandido por `.glassEffect(.regular, in: .rect(cornerRadius: 26))`.
- Reemplazar el `Canvas` con AI gradient orbits (spec 02) por un `Color` tinte animado con `.glassEffect(.regular.tint(...))`.
- Envolver la cápsula colapsada (con audio) y los controles de medios en un `GlassEffectContainer` para que el sistema agrupe los elementos glass correctamente.
- Aplicar `.glassEffect(.regular.interactive(), in: .capsule)` a cada botón de control (play/pause, prev, next) para que el sistema los considere interactivos.
- Aplicar `.glassEffect(.regular, in: .capsule)` al `controlsCapsule` background.
- Aplicar `.glassEffect(.regular, in: .capsule)` al slider de progreso (track).
- Mantener el gradient AI animado como `Color` overlay (no `Canvas`) que se anima con `TimelineView`.
- Migrar la cápsula colapsada a `glassEffect` capsule cuando el tema es Liquid Glass.
- El tema Solid Black sigue usando `Color.black` puro sin glass.
- `LiquidGlassTheme` se actualiza para usar `.glassEffect` en sus backgrounds (en lugar de capas `.fill` caseras).
- Documentar en el código que la API requiere macOS 26+ (ya garantizado por el deployment target 26.5).

### Excluido

- **Animación de tinte dinámica** entre los 4 colores AI (el spec actual muestra los 4 a la vez; un spec futuro podría alternar entre ellos). Se mantiene la misma visualización.
- **Tinte por track** (color derivado del artwork) — fuera de alcance, se difiere.
- **Glass en la cápsula colapsada del tema Solid Black** — el tema "Solid Black" no usa glass por definición.
- **Glass en el `LiquidNotch.dmg`** — irrelevante.
- **Reescritura de `CollapsedNotchView`, `ExpandedGlassView`, `MainNotchView` (vistas muertas)** — ya cubierto por el spec 08 (Dynamic Island behavior).
- **Custom shaders con Metal** — fuera de alcance, el spec usa solo primitivas de SwiftUI.
- **Glass en los iconos de las apps** (música, etc.) — fuera de alcance.
- **Soporte para macOS < 26** — el deployment target es 26.5, no se necesita fallback. Si en el futuro se baja el target, se añade `#available` con fallback a `.ultraThinMaterial` (esto ya se documenta en la guía oficial de Apple).

## File Structure (cambios)

```text
LiquidNotch/
├── LiquidNotch/
│   ├── Themes/
│   │   ├── LiquidGlassTheme.swift      # MODIFICAR — usar glassEffect
│   │   ├── SolidBlackTheme.swift       # sin cambios
│   │   ├── NotchThemeApplying.swift    # sin cambios
│   │   └── ThemePalette.swift          # sin cambios
│   └── Views/
│       └── UnifiedNotchView.swift      # MODIFICAR — refactor backgrounds con glassEffect
└── specs/
    └── 07-liquid-glass-real-apple-api.md
```

## Contexto de la API (Apple docs)

Per la documentación oficial de Apple para SwiftUI en iOS 26 / macOS 26:

| API | Uso |
|---|---|
| `view.glassEffect(_:in:)` | Aplica el efecto Liquid Glass. Por defecto, variante `.regular` con forma capsule anclada al frame de la vista. |
| `Glass.regular` | Variante "regular" del material. Translúcido, refleja el contenido detrás, con borde sutil. |
| `Glass.regular.interactive()` | Variante interactiva. Usar **solo** en elementos tappables. |
| `Glass.regular.tint(_:)` | Aplica un tinte de color encima del glass (ej. naranja, azul). El tinte se anima si se anima la `Color`. |
| `GlassEffectContainer { ... }` | Agrupa múltiples elementos glass para que se rendericen como una sola capa (más eficiente y correcto visualmente, ya que **glass no puede samplear otros glass**). |
| `view.glassBackgroundEffect(_:in:displayMode:)` | Equivalente a `glassEffect` pero como background con display mode configurable. Disponible en visionOS 2.4+ también. |

**Reglas oficiales** (de la guía de Apple vía context7):

1. `glassEffect` se aplica **al final** de la cadena de modificadores (después de `font`, `foregroundStyle`, `padding`, `frame`).
2. Usar `GlassEffectContainer` para agrupar elementos glass (no anidar containers innecesariamente).
3. Usar `.interactive()` solo en elementos clickeables.
4. No aplicar glass a cada elemento: usar con moderación.
5. No mezclar `cornerRadius` arbitrariamente dentro de un container.
6. No añadir backgrounds oscuros detrás de toolbars (confunde con scroll edge effect).
7. `glass` no puede samplear otros `glass`: por eso los elementos glass deben estar en un `GlassEffectContainer`.

**Versión requerida**: macOS 26.0+. Ya garantizado por `MACOSX_DEPLOYMENT_TARGET = 26.5`.

## Data Model

No hay nuevos modelos. Los cambios son puramente de presentación.

## Implementation Plan

### Fase 1 — Actualizar `LiquidGlassTheme` para usar glassEffect

**Archivo**: `Themes/LiquidGlassTheme.swift` (modificar).

El `collapsedBackground` y `expandedBackground` pasan de ser `ZStack` de fills a vistas que aplican `glassEffect` sobre un `Color` tinte.

```swift
struct LiquidGlassTheme: NotchThemeApplying {
    let id: NotchTheme = .liquidGlass
    let cornerRadius: CGFloat = 26
    let collapsedCornerRadius: CGFloat = 24
    let idleGradientEnabled = true
    let idleGradientOpacity: Double = 0.4
    let idleIndicatorEnabled = true
    let idlePulseDuration: Double = 0.6
    let borderWidth: CGFloat = 0.0           // Apple ya pone el borde via glassEffect
    let borderOpacity: Double = 0.0
    let transitionDuration: Double = 0.4

    var collapsedBackground: AnyView {
        AnyView(
            Capsule()
                .fill(Color.black.opacity(0.001))  // base casi transparente
                .glassEffect(.regular, in: .capsule)
        )
    }

    var expandedBackground: AnyView {
        AnyView(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.001))
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        )
    }
}
```

**Notas**:
- `Color.black.opacity(0.001)` es necesario para que el `RoundedRectangle` tenga un `Shape` que reciba el `glassEffect`. La opacidad 0.001 es invisible pero da contenido al nodo de SwiftUI.
- `borderWidth = 0.0` y `borderOpacity = 0.0` porque Apple ya añade un borde sutil al `glassEffect`. El doble borde se ve mal.
- El `LiquidGlassTheme` ya no necesita `glassWhite` ni `glassBorderOpacity`; el sistema se encarga.

**Verificación**: el proyecto compila; la cápsula colapsada y expandida muestran el efecto glass oficial (no `.ultraThinMaterial`).

### Fase 2 — Refactor del background expandido en `UnifiedNotchView`

**Archivo**: `Views/UnifiedNotchView.swift` (modificar).

Cambios:
1. Eliminar el `ZStack` actual con 3 capas (`Color.black.opacity(0.15)` + `Color.white.opacity(0.08)` + `animatedAIGradient` con `blur(35)`).
2. Reemplazar por `themeManager.resolved.expandedBackground` (que ya viene con `glassEffect` aplicado).
3. Sobre ese background, dibujar el `animatedAIGradient` con un nuevo enfoque:
   - En lugar de `Canvas` con 4 círculos grandes, usar **un `LinearGradient` o `AngularGradient` con tinte derivado de los 4 colores AI**, animado con `TimelineView`.
   - Aplicar este gradient como `Color` overlay con `.opacity(theme.idleGradientOpacity)` y `.allowsHitTesting(false)`.
   - El gradient se anima rotando (`hueRotation`) en vez de moviendo 4 círculos separados.

```swift
private var animatedAITint: some View {
    TimelineView(.animation(minimumInterval: 0.05)) { timeline in
        let time = timeline.date.timeIntervalSinceReferenceDate
        let angle = time * 8  // grados por segundo

        AngularGradient(
            colors: ThemePalette.aiColors + [ThemePalette.aiColors[0]],
            center: .center,
            angle: .degrees(angle.truncatingRemainder(dividingBy: 360))
        )
        .blur(radius: 40)
        .opacity(themeManager.resolved.idleGradientOpacity)
    }
    .allowsHitTesting(false)
}
```

> **Decisión**: `AngularGradient` rotando es visualmente más cercano al "gradient Apple Intelligence" oficial que 4 círculos con orbit. Y funciona correctamente con `glassEffect` (no hay conflicto de sampling). Ver decisiones.

4. El overlay se aplica con `ZStack { background; animatedAITint; content }`.

**Verificación**: el efecto glass se ve con un tinte AI girando lentamente detrás. Sin `Canvas` con 4 elipses.

### Fase 3 — `GlassEffectContainer` en el expanded view

**Archivo**: `Views/UnifiedNotchView.swift` (modificar).

Cambios:
1. Envolver el `ExpandedContentView` (artwork + metadata + controles) en un `GlassEffectContainer` con `spacing: 16`.
2. Dentro del container, cada botón de control aplica `.glassEffect(.regular.interactive(), in: .capsule)` sobre su contenido.
3. El `controlsCapsule` contenedor (que tiene fondo glass) aplica `.glassEffect(.regular, in: .capsule)` a su `Capsule` background.

```swift
GlassEffectContainer(spacing: 16) {
    HStack(spacing: 16) {
        artworkView
        metadataAndControlsView
    }
}
```

> El `artworkView` y el `metadataAndControlsView` pueden tener sus propios `.glassEffect`; el container los agrupa para que el sistema los procese como una sola capa.

**Verificación**: los 3 botones de control (prev, play/pause, next) tienen el efecto glass interactivo al hacer hover; el slider de progreso tiene track glass.

### Fase 4 — Botones de control con `.interactive()`

**Archivo**: `Views/UnifiedNotchView.swift` (modificar, en `controlsCapsule`).

```swift
HStack(spacing: 28) {
    Button(action: onPrevious) {
        Image(systemName: "backward.fill")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .glassEffect(.regular.interactive(), in: .circle)
    }
    .buttonStyle(.plain)

    // play/pause y next con el mismo patrón
}
```

**Verificación**: cada botón responde al `:hover` con el realce glass oficial; el click tiene un ripple sutil.

### Fase 5 — Slider de progreso glass

**Archivo**: `Views/UnifiedNotchView.swift` (modificar, en `progressView`).

```swift
GeometryReader { geo in
    ZStack(alignment: .leading) {
        Capsule()
            .fill(Color.white.opacity(0.25))
            .frame(height: 4)
            .glassEffect(.regular, in: .capsule)

        Capsule()
            .fill(Color.white)
            .frame(width: max(0, min(geo.size.width * CGFloat(progress), geo.size.width)), height: 4)
    }
    // ... DragGesture
}
```

**Verificación**: el track del slider tiene glass sutil; el fill blanco sigue siendo opaco.

### Fase 6 — Cápsula colapsada con glass

**Archivo**: `Views/UnifiedNotchView.swift` (modificar, `CapsuleBarView` o background colapsado).

Cuando `notchState.isExpanded == false` y el tema es Liquid Glass, el background colapsado (que es `themeManager.resolved.collapsedBackground`) ya tiene `glassEffect(.regular, in: .capsule)`. Verificar que se ve correctamente sobre el fondo de la pantalla (que es lo que debe reflejar el glass).

**Verificación**: el glass se ve con el contenido del escritorio detrás difuminado.

### Fase 7 — Tema Solid Black intacto

**Archivo**: `Themes/SolidBlackTheme.swift` — sin cambios.

El `Color.black` puro no usa `glassEffect`. La verificación es que NO se importa glassEffect en este archivo y que visualmente sigue siendo negro sólido.

**Verificación**: cambiar a Solid Black y verificar que el background es `Color.black` puro (no glass).

## Acceptance Criteria

- [ ] El archivo `Themes/LiquidGlassTheme.swift` usa `glassEffect(_:in:)` y NO contiene `.ultraThinMaterial`.
- [ ] El archivo `Themes/SolidBlackTheme.swift` no usa `glassEffect` ni `.ultraThinMaterial`.
- [ ] El expanded view tiene un `GlassEffectContainer` envolviendo el contenido.
- [ ] Cada botón de control (prev, play/pause, next) tiene `.glassEffect(.regular.interactive(), in: .circle)` aplicado.
- [ ] El `controlsCapsule` background tiene `.glassEffect(.regular, in: .capsule)`.
- [ ] El track del slider de progreso tiene `.glassEffect(.regular, in: .capsule)`.
- [ ] El background expandido es `RoundedRectangle` con `.glassEffect(.regular, in: .rect(cornerRadius: 26))` y un `Color` tinte AI overlay animado.
- [ ] El background colapsado (con tema Liquid Glass) es `Capsule` con `.glassEffect(.regular, in: .capsule)`.
- [ ] NO existe ningún `Canvas` con 4 elipses AI en `UnifiedNotchView`.
- [ ] El gradient AI animado se implementa con `AngularGradient` rotando.
- [ ] Cambiar de Liquid Glass a Solid Black y viceversa funciona sin recompilar (cross-fade del spec 06 sigue funcionando).
- [ ] El tema Solid Black sigue viéndose como `Color.black` puro sin glass.
- [ ] El proyecto compila sin warnings de `glassEffect` o `Glass` deprecated.
- [ ] `xcodebuild -showBuildSettings` muestra `MACOSX_DEPLOYMENT_TARGET = 26.5`.
- [ ] El proyecto compila sin necesidad de `#available(macOS 26, *)` checks (target es 26.5).

## Decisiones tomadas

- **Sí: `glassEffect(.regular, in: ...)` con `in:`** — la forma explícita de la API, evita sorpresas con `DefaultGlassEffectShape` (que es capsule, queremos rect en expanded).
- **No: `glassEffect()` a secas** — usa `.capsule` por defecto, no apropiado para el rect del expanded.
- **Sí: `Color.black.opacity(0.001)` como base** — la API requiere un fill antes de aplicar glass; 0.001 es invisible pero da el `Shape` necesario.
- **No: `Color.clear`** — `.glassEffect` puede tener problemas de render con clear en algunos casos; 0.001 es más seguro.
- **Sí: `AngularGradient` rotando en vez de 4 elipses con orbit** — el API `glassEffect` no puede samplear otros glass, así que poner 4 elipses con blur como overlay se renderiza mal. `AngularGradient` rotando es más limpio y se ve igual de bien.
- **No: Mantener el `Canvas` con 4 elipses** — visualmente más cercano a spec 02 pero técnicamente incompatible con glassEffect (over-blur produce artefactos).
- **Sí: Sin `#available` checks** — el deployment target es 26.5, la API es estable.
- **No: `#available(macOS 26, *)` con fallback** — el target ya es 26.5, el check es ruido.
- **Sí: `borderWidth = 0.0` en `LiquidGlassTheme`** — el sistema ya añade borde al glassEffect; el borde custom se ve doble.
- **No: `borderWidth = 0.5`** — duplica el borde nativo, se ve peor.
- **Sí: `GlassEffectContainer` con `spacing: 16`** — coincide con el `HStack(spacing: 16)` del expanded.
- **No: Sin container (múltiples glass sueltos)** — el sistema no puede agrupar el rendering, peor performance.
- **Sí: `.glassEffect(.regular.interactive(), in: .circle)` en botones** — círculo es la forma natural de los SF Symbols como botones.
- **No: `.glassEffect(.regular.interactive(), in: .capsule)` en botones** — cápsula en un botón circular se ve rara.
- **Sí: Mantener el spec 06 (temas) intacto** — el `LiquidGlassTheme` cambia internamente, pero la API pública (`NotchThemeApplying`) no.

## Riesgos

| Riesgo | Mitigación |
|---|---|
| `glassEffect` no se ve igual que `.ultraThinMaterial` (puede verse más opaco o más claro) | Diff visual con screenshot antes/después; ajustar opacidades en `idleGradientOpacity` si es necesario |
| `AngularGradient` rotando se ve menos "orgánico" que 4 elipses con orbit | Es la solución técnica correcta; el usuario aprueba si el efecto visual sigue siendo AI-style |
| `glassEffect` con `Color.black.opacity(0.001)` produce un black flash al cargar | 0.001 es prácticamente invisible; si aparece, subir a 0.01 o usar `Color.white.opacity(0.001)` |
| `GlassEffectContainer` afecta el layout (spacing se suma al layout spacing) | El `spacing: 16` del container coincide con el `HStack(spacing: 16)`; no debería haber cambio |
| El sistema tarda en "activar" el glass la primera vez | Comportamiento nativo; no es un bug. Se documenta en el README |
| `glassEffect` no soporta `Color.clear` ni `Color.black.opacity(0)` como base | Por eso usamos 0.001 |
| Si Apple cambia la API de glass en una versión futura de macOS 26.x | El deployment target está pineado, los cambios vendrían en macOS 27+; se documenta en CHANGELOG |
| El tema Solid Black accidentalmente hereda el glass del Liquid Glass | Se verifica con test visual al cambiar; `SolidBlackTheme` no llama a `glassEffect` |

## Verification final

```bash
# Build limpio
xcodebuild -project LiquidNotch.xcodeproj -scheme LiquidNotch -destination 'platform=macOS' clean build

# Verificar que glassEffect se usa
grep -c "glassEffect" LiquidNotch/Themes/LiquidGlassTheme.swift  # >= 1
grep -c "glassEffect" LiquidNotch/Views/UnifiedNotchView.swift   # >= 3 (background, container, buttons)

# Verificar que NO hay Canvas con 4 elipses AI
grep -c "Canvas" LiquidNotch/Views/UnifiedNotchView.swift  # 0

# Verificar que NO hay .ultraThinMaterial (reemplazado)
grep -c "ultraThinMaterial" LiquidNotch/ -r  # 0

# Verificar que SolidBlack NO usa glass
grep -c "glassEffect" LiquidNotch/Themes/SolidBlackTheme.swift  # 0

# Verificar deployment target
xcodebuild -showBuildSettings -project LiquidNotch.xcodeproj -scheme LiquidNotch | grep MACOSX_DEPLOYMENT_TARGET
# debe imprimir: MACOSX_DEPLOYMENT_TARGET = 26.5
```

## What is **NOT** in this spec

- Animación de tinte dinámica entre los 4 colores AI.
- Tinte por track (color derivado del artwork).
- Glass en la cápsula colapsada del tema Solid Black.
- Glass en iconos de apps.
- Reescritura de las vistas muertas (spec 08).
- Custom shaders con Metal.
- Soporte para macOS < 26 (el target es 26.5).

Cada uno, si aterriza, va en su propio spec.
