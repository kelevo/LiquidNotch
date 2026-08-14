# Spec: 02 — Visual Adjustments: App Icon, Compact Height & Apple Intelligence Gradient

- **Estado**: Implementando
- **Fecha**: 2026-08-14
- **Depende de**: Spec 01 (Island Notch Overlay Base)
- **Autor**: opencode
- **Plataforma**: macOS only (Apple Silicon)

## Objetivos
- Ajustar el estado colapsado para que no contacte los bordes de la barra de tareas.
- Mostrar el icono de la app de origen (Apple Music / Spotify) en el widget colapsado en lugar de la carátula.
- Mantener la carátula solo en el estado expandido.
- Mejorar el efecto Liquid Glass en el estado expandido con un degradado animado inspirado en los colores de Apple Intelligence (rojo, azul, rosa, naranja), manteniendo translucidez.

## Cambios Detallados

### 1. Altura del Estado Colapsado

**Problema**: El panel colapsado (170x30) toca el borde superior de la pantalla, solapándose con la barra de tareas.

**Solución**:
- Reducir tamaño de `170x30` a `170x24` (6px menos de altura).
- Agregar offset de 4px en `positionAtNotch()` para separarlo del borde superior: `maxY - panelHeight - 4`.

**Archivos afectados**:
- `App/AppDelegate.swift` — constantes `panelWidth`/`panelHeight`, función `positionAtNotch()`, función `resizePanel(expanded:)`.

### 2. Icono de App de Origen en Estado Colapsado

**Problema**: El widget colapsado muestra la carátula de la canción, que es pequeña y no identifica la app de origen.

**Solución**:
- Agregar campo `appIcon: NSImage?` a `TrackInfo`.
- En `MediaRemoteManager`, obtener el icono de la app vía `NSRunningApplication.runningApplications(withBundleIdentifier:).first?.icon`.
- Cachear iconos por `bundleId` (no cambian durante la vida de la app).
- `CollapsedNotchView` muestra `appIcon` en lugar de `artworkImage`.
- Fallback a SF Symbol `music.note` si no se puede obtener el icono.

**Archivos afectados**:
- `Models/TrackInfo.swift` — nuevo campo `appIcon`.
- `Services/MediaRemoteManager.swift` — función para obtener icono, caché por bundleId.
- `Views/CollapsedNotchView.swift` — usar `appIcon` en la vista.

### 3. Carátula Solo en Estado Expandido

**Resultado**: Implícito en el cambio 2. El colapsado muestra icono de app; el expandido (`ExpandedGlassView`) ya muestra la carátula. Sin cambios adicionales necesarios en `ExpandedGlassView`.

### 4. Liquid Glass Mejorado con Degradado Apple Intelligence

**Problema**: El glass actual es demasiado opaco y no tiene personalidad visual distintiva. Los cortes en el degradado se ven abruptos al cambiar de posición.

**Solución**:
- **Capa 1 (material)**: `RoundedRectangle(cornerRadius: 26).fill(.ultraThinMaterial)` — material con bordes redondeados.
- **Capa 2 (fill glass)**: `RoundedRectangle(cornerRadius: 26).fill(Color.white.opacity(0.05))` — glass blanco sutil al 5%.
- **Capa 3 (degradado)**: `animatedAIGradient.blur(50).opacity(0.25)` — colores Apple Intelligence visibles al 25%.
- Degradado animado Apple Intelligence con **órbitas independientes**:
  - 4 colores fijos, cada uno posicionado en una esquina del rectángulo.
  - Cada círculo tiene velocidad angular independiente (0.07-0.10 rad/s).
  - Posiciones base: ángulos fijos por esquina (135°, 45°, 225°, 315°).
  - "Wobble" orgánico: `sin()` y `cos()` con amplitud 0.10-0.15.
  - Radio de los círculos: `1.8x` del tamaño del contenedor (muy grandes, bordes difusos).
  - **Sin `rotateColors()`** — se elimina la función que causaba snaps.
  - `blur(radius: 40)` para suavizar bordes y mezclar colores.
  - Opacidad final del degradado: `0.07` (un tercio de la anterior).
- Mantener borde blanco glass y sombra existentes.

**Parámetros de órbitas**:

| Círculo | Color | Posición base | Velocidad | Wobble | Radio |
|---|---|---|---|---|---|
| 0 | Naranja `#F19B33` | Superior izquierda (135°) | 0.08 | 0.12 | 1.2x |
| 1 | Rosa `#F93562` | Superior derecha (45°) | 0.09 | 0.15 | 1.2x |
| 2 | Azul `#33AAE6` | Inferior izquierda (225°) | 0.07 | 0.10 | 1.2x |
| 3 | Púrpura `#DC83EE` | Inferior derecha (315°) | 0.10 | 0.13 | 1.2x |

**Offsets de movimiento**: `0.55` (X) / `0.50` (Y) — círculos bien distribuidos dentro del área visible.

**Archivos afectados**:
- `Views/ExpandedGlassView.swift` — background con material ultra-thin + degradado con órbitas independientes.

## Paleta Apple Intelligence

| Color | Hex | RGB | Posición base |
|---|---|---|---|
| Naranja | `#F19B33` | `(0.945, 0.608, 0.200)` | Superior izquierda |
| Rosa | `#F93562` | `(0.976, 0.208, 0.384)` | Superior derecha |
| Azul | `#33AAE6` | `(0.200, 0.667, 0.902)` | Inferior izquierda |
| Púrpura | `#DC83EE` | `(0.863, 0.514, 0.933)` | Inferior derecha |

## Tamaños Finales

| Estado | Ancho | Alto | Notas |
|---|---|---|---|
| Colapsado | 170px | 24px | Offset Y: -4px del borde superior |
| Expandido | 370px | 160px | Sin cambios |

## Seguridad

- No se encontraron credenciales ni tokens sensibles en el proyecto.
- Los AppleScript son estáticos y no interpolan datos del usuario.
- Se recomienda agregar `.gitignore` para excluir `xcuserdata/`.

## Verification

- Build para macOS debe completar sin errores.
- El widget colapsado no debe tocar el borde superior de la pantalla.
- El widget colapsado debe estar centrado vertical y horizontalmente en la barra de tareas.
- El widget colapsado debe mostrar el icono de Apple Music o Spotify.
- Al expandir, el glass debe tener 3 capas visibles:
  - Material UltraThin con bordes redondeados (cornerRadius: 26).
  - Fill blanco glass al 5% con bordes redondeados.
  - Degradado Apple Intelligence al 25% con 4 colores visibles (naranja, rosa, azul, púrpura).
- Sin bordes cuadrados visibles — todos los elementos respetan cornerRadius.
- Los 4 colores deben estar distribuidos en sus esquinas correspondientes.
- El degradado debe rotar suavemente y de forma continua (sin snaps).
- La carátula solo debe aparecer en el estado expandido.
