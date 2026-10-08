# Spec: 03 — Media Controls, Seek Improvements & Collapse Glow Animation

- **Estado**: Implementando
- **Fecha**: 2026-08-14
- **Depende de**: Spec 02 (Visual Adjustments)
- **Autor**: opencode
- **Plataforma**: macOS only (Apple Silicon)

## Objetivos
- Asegurar que los controles de medios (play/pause, next, previous) funcionen correctamente.
- Mejorar la barra de progreso con animación suave y seek sin interrupciones.
- Agregar animación de brillo alrededor de la cápsula colapsada después de hacer hover.

## Estado Actual

| Función | Estado | Detalle |
|---|---|---|
| Play/Pause | ✅ Funcional | `togglePlayPause()` con AppleScript |
| Next/Previous | ✅ Funcional | `skipNext()` / `skipPrevious()` |
| Seek (barra) | ⚠️ Funcional con issues | DragGesture sin debouncing, polling interrumpe |
| Progreso suave | ❌ No existe | Solo actualiza cada 2 segundos (polling) |
| Glow al colapsar | ❌ No existe | Solo borde estático blanco |

## Cambios

### 1. Progreso Suave — Timer Local de Elapsed

**Problema**: La barra de progreso solo se actualiza cada 2 segundos (polling), causando saltos visibles.

**Solución**: Timer local de 1 segundo que incrementa `elapsedTime` cuando `isPlaying == true`.

**Parámetros**:
- Intervalo: 1.0 segundos
- Inicio: Cuando `isPlaying == true` después de `fetchNowPlaying()`
- Fin: Cuando `isPlaying == false` o `currentTrack == nil`
- Comportamiento: Incrementa `elapsedTime` en 1.0, sin exceder `duration`

**Archivos**: `MediaRemoteManager.swift`

### 2. Seek con Debouncing

**Problema**: El `DragGesture` envía 60+ llamadas AppleScript por segundo durante el drag.

**Solución**: Debouncing de 0.1 segundos — solo envía el último valor del drag.

**Parámetros**:
- Intervalo de debounce: 0.1 segundos
- Comportamiento: Invalida timer anterior, programa nuevo timer de 0.1s

**Archivos**: `MediaRemoteManager.swift`

### 3. Flag `isSeeking`

**Problema**: El polling de 2 segundos puede sobreescribir la posición durante un seek activo.

**Solución**: Flag `isSeeking` que suprime `fetchNowPlaying()` durante el drag.

**Parámetros**:
- `isSeeking = true`: Al comenzar drag (`.onChanged`)
- `isSeeking = false`: Al terminar drag (`.onEnded`)

**Archivos**: `MediaRemoteManager.swift`, `ExpandedGlassView.swift`

### 4. Animación de Brillo al Colapsar

**Problema**: No hay feedback visual al colapsar el notch.

**Solución**: Borde animado con colores Apple Intelligence que aparece y se desvanece.

**Comportamiento**:
1. Hover exit → notch comienza a colapsar
2. Vista colapsada aparece → `onAppear` activa `showGlow = true`
3. Borde AngularGradient con 4 colores AI aparece
4. Blur de 4px para efecto glow
5. Fade out en 0.5 segundos

**Parámetros**:
- Colores: Apple Intelligence (naranja, rosa, azul, púrpura)
- Tipo: AngularGradient en Capsule
- Blur: 4px
- Duración fade: 0.5 segundos
- Opacidad máxima: 0.8

**Archivos**: `CollapsedNotchView.swift`

## Archivos a Modificar

| Archivo | Cambios |
|---|---|
| `Services/MediaRemoteManager.swift` | Timer elapsed, debouncing seek, flag isSeeking |
| `Views/ExpandedGlassView.swift` | Estado isSeeking en drag gesture |
| `Views/CollapsedNotchView.swift` | Animación de glow |

## Verification

- Barra de progreso se mueve suavemente cada segundo (no cada 2)
- Al hacer drag en la barra, la posición se actualiza sin saltos
- Al colapsar el notch, aparece glow AI que se desvanece en 0.5s
- Botones play/pause, next, previous funcionan correctamente
- Build sin errores
