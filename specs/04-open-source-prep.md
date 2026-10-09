# Spec: 04 — Open Source Prep: README, LICENSE, .gitignore, CI, Cleanup

- **Estado**: Approved
- **Fecha**: 2026-10-08
- **Depende de**: N/A (preparación base)
- **Autor**: opencode
- **Plataforma**: macOS only (Apple Silicon)

## Objetivos

Preparar el proyecto LiquidNotch para su release público como proyecto open-source en GitHub: documentación de entrada (README, LICENSE, CONTRIBUTING, CHANGELOG), archivo `.gitignore` adecuado, GitHub Actions para verificación de build, limpieza de binarios y de targets móviles (iOS/visionOS) que ya no se usan.

Una vez ejecutado este spec, el repositorio queda listo para ser publicado en `https://github.com/kelevo/LiquidNotch` con una primera release.

## Alcance (Scope)

### Incluido

- **`LICENSE`**: MIT, copyright 2026 kelevo.
- **`README.md`**: descripción, características, requisitos, build, install, contributing, license, badges.
- **`.gitignore`**: exclusiones estándar Xcode + `LiquidNotch.dmg`, `xcuserdata/`, `DerivedData/`, `build/`, `.DS_Store`.
- **`CONTRIBUTING.md`**: flujo de PRs, estilo de commits, convenciones del proyecto.
- **`CHANGELOG.md`**: formato "Keep a Changelog", entrada inicial `0.1.0`.
- **`.github/workflows/build.yml`**: GitHub Actions en `macos-14` que verifica que el proyecto compila para macOS en cada PR y push a `main`.
- **Mover `LiquidNotch.dmg` a GitHub Releases** y eliminarlo del tracking de git.
- **Eliminar targets iOS y visionOS** del `.xcodeproj` (queda solo macOS).
- **Eliminar claves iOS-específicas** del `.pbxproj` (`UIApplicationSceneManifest_Generation`, `UILaunchScreen_Generation`, `UIStatusBarStyle`, `UISupportedInterfaceOrientations_*`).
- **Actualizar `AGENTS.md`**: reflejar macOS-only, eliminar comandos de build para iOS/visionOS.
- **Limpiar `AppIcon.appiconset/Contents.json`**: dejar solo entradas `idiom = "mac"`.
- **Eliminar `Info.plist` keys iOS** vía la configuración del `.pbxproj` (`INFOPLIST_KEY_UIApplicationSceneManifest_Generation`, etc.).

### Excluido

- **Code signing y notarización** — se distribuye sin firmar (`CODE_SIGN_IDENTITY = "-"`, sin Developer ID).
- **Homebrew tap / Cask** — se difiere a un spec posterior si la comunidad lo pide.
- **Sparkle auto-updater** — fuera de alcance.
- **Sitio web / docs site** (GitHub Pages) — fuera de alcance.
- **App Store submission** — proyecto explícitamente no compatible con App Store (por `MediaRemote` privado en spec 10).
- **Traducción de README a otros idiomas** — solo español e inglés en este spec; otros idiomas se aceptan como PRs.
- **Renombrar el proyecto / cambiar bundle ID** — se mantiene `kelevo.LiquidNotch`.

## File Structure (cambios)

```text
LiquidNotch/                         (raíz del repo)
├── .github/
│   └── workflows/
│       └── build.yml                 # NUEVO — GitHub Actions
├── .gitignore                        # NUEVO
├── AGENTS.md                         # MODIFICAR — macOS only
├── CHANGELOG.md                      # NUEVO
├── CONTRIBUTING.md                   # NUEVO
├── LICENSE                           # NUEVO — MIT
├── LiquidNotch.dmg                   # BORRAR del tracking
├── LiquidNotch.xcodeproj/            # MODIFICAR — quitar iOS/visionOS
│   └── project.pbxproj
├── LiquidNotch/
│   └── Assets.xcassets/
│       └── AppIcon.appiconset/
│           └── Contents.json         # MODIFICAR — solo entradas mac
├── README.md                         # NUEVO
└── specs/
    ├── 01-...md                      # existente
    ├── 02-...md
    ├── 03-...md
    ├── 04-open-source-prep.md        # este spec
    ├── .spec-config.yml              # NUEVO — workflow config
    └── 05-...  (siguiente)
```

## Implementation Plan

### Fase 1 — `.gitignore` raíz

**Archivo**: `.gitignore` (crear).

Contenido agrupado por secciones:
- **macOS / Xcode**: `*.dmg`, `*.app`, `xcuserdata/`, `*.xcuserstate`, `DerivedData/`, `build/`, `*.xcworkspace/xcuserdata/`, `*.xcodeproj/xcuserdata/`, `*.xcodeproj/project.xcworkspace/xcuserdata/`.
- **Swift Package Manager**: `.build/`, `Packages/`, `*.xcodeproj/project.xcworkspace/xcuserdata/`, `Package.resolved`.
- **General**: `.DS_Store`, `.AppleDouble`, `.LSOverride`, `Icon?`, `._*`, `.Spotlight-V100`, `.Trashes`.
- **IDE**: `.idea/`, `*.swp`, `*.swo`, `*.vscode/`.
- **Secrets**: `.env`, `.env.local`, `*.p12`, `*.cer`, `*.key`.

**Verificación**: `git status` no debe mostrar archivos ignorados.

### Fase 2 — `LICENSE` MIT

**Archivo**: `LICENSE` (crear).

Texto estándar de MIT License con `Copyright (c) 2026 kelevo`.

**Verificación**: `head -1 LICENSE` muestra `MIT License`.

### Fase 3 — `README.md`

**Archivo**: `README.md` (crear).

Secciones obligatorias en este orden:
1. **Hero**: nombre del proyecto + tagline corto.
2. **Badges**: `[MIT License]`, `[macOS 26.5+]`, `[Apple Silicon]` (shields.io).
3. **Screenshot / GIF**: placeholder `docs/screenshot.png` (no se incluye en este spec, se documenta como contribución futura).
4. **Features**: lista de las 7 features del proyecto (referenciando los specs correspondientes).
5. **Why**: 1-2 párrafos explicando la motivación (iPhone Dynamic Island en macOS, sin App Store).
6. **Requirements**: macOS 26.5+, Apple Silicon, Xcode 16+.
7. **Build**: comando `xcodebuild` (idéntico al de `AGENTS.md`).
8. **Run**: `open LiquidNotch.xcodeproj` → ⌘R.
9. **Install (release)**: link a GitHub Releases + nota de "no firmado, requiere Gatekeeper override".
10. **Configuration**: enlace al spec 05 (Settings).
11. **Project Status**: tabla con specs 01-10 y sus estados.
12. **Known Limitations**: API privada de MediaRemote (spec 10), no compatible con App Store, no firmado.
13. **Contributing**: enlace a `CONTRIBUTING.md`.
14. **License**: `MIT — see [LICENSE](./LICENSE)`.
15. **Acknowledgments**: créditos a Apple por Liquid Glass, a la comunidad SwiftUI.

**Verificación**: renderiza correctamente en GitHub.

### Fase 4 — `CONTRIBUTING.md`

**Archivo**: `CONTRIBUTING.md` (crear).

Secciones:
1. **Code of Conduct** (enlace a uno futuro — placeholder en este spec).
2. **Bug reports**: usar GitHub Issues con template (referenciar `.github/ISSUE_TEMPLATE/` si existiera, se omite en este spec).
3. **Pull Requests**:
   - Branch naming: `feat/<short-desc>`, `fix/<short-desc>`, `spec/<NN>-<slug>`.
   - Commits: imperativo, español o inglés consistente.
   - Specs: cualquier feature nueva > 1 archivo debe tener un spec en `specs/` antes del PR.
4. **Style guide**:
   - Swift 5.0, `@MainActor` por defecto, no comments salvo los necesarios.
   - 4 espacios de indentación (default Xcode).
   - `liquidNotch.*` para `UserDefaults` keys.
   - No editar `project.pbxproj` manualmente (auto-sync).
5. **Testing manual**: comandos de build de `AGENTS.md`.

### Fase 5 — `CHANGELOG.md`

**Archivo**: `CHANGELOG.md` (crear).

Formato "Keep a Changelog 1.1.0". Entrada inicial:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-10-08

### Added
- Initial release: macOS notch overlay with Liquid Glass music player.
- Apple Music and Spotify integration via AppleScript.
- Hover-to-expand interaction with spring animations.
- Apple Intelligence gradient orbits (orange, pink, blue, purple).
- Mini equalizer visualization in collapsed state.
- Open-source release infrastructure (README, LICENSE, CI).
```

### Fase 6 — GitHub Actions CI

**Archivo**: `.github/workflows/build.yml` (crear).

```yaml
name: Build

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    runs-on: macos-14
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.0.app
      - name: Build
        run: |
          xcodebuild \
            -project LiquidNotch.xcodeproj \
            -scheme LiquidNotch \
            -destination 'platform=macOS' \
            -configuration Debug \
            CODE_SIGN_IDENTITY="-" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO \
            build | xcpretty
      - name: Upload artifact
        if: success()
        uses: actions/upload-artifact@v4
        with:
          name: LiquidNotch-Debug
          path: build/Build/Products/Debug/LiquidNotch.app
```

**Notas**:
- `macos-14` (Apple Silicon) porque el deployment target es 26.5 y el proyecto es Apple Silicon only.
- `CODE_SIGN_IDENTITY = "-"` firma ad-hoc para que el binario corra.
- `xcpretty` se invoca si está disponible; sin él, xcodebuild sigue corriendo y los warnings no fallan el build.
- Subir el `.app` como artifact permite descargar el binario desde el run.

### Fase 7 — Limpiar `LiquidNotch.dmg` y DMG existente

Pasos:
1. `git rm LiquidNotch.dmg`.
2. `git commit -m "chore: remove LiquidNotch.dmg from tracking (will be released via GitHub Releases)"`.
3. Documentar en el README que las releases se publican en la pestaña **Releases** del repo (futuro).
4. **No** se regenera el DMG en este spec — se difiere a un spec posterior ("Release pipeline") o se hace manualmente la primera vez.

### Fase 8 — Eliminar targets iOS y visionOS

**Archivo**: `LiquidNotch.xcodeproj/project.pbxproj` (modificar con Xcode, **nunca a mano**).

Pasos manuales en Xcode:
1. Abrir `LiquidNotch.xcodeproj`.
2. En el panel de targets, click derecho sobre el target iOS → "Delete" → "Remove References" (no "Move to Trash", porque queremos conservar el historial).
3. Repetir con el target visionOS.
4. Verificar que el archivo `project.pbxproj` ya no contiene las claves:
   - `iphonesimulator`, `iphoneos`, `xros`, `xrsimulator` en `SDKROOT`.
   - `TARGETED_DEVICE_FAMILY = 1,2` (queda `6` para macOS).
   - `INFOPLIST_KEY_UI*` (todas las keys iOS).
5. `xcodebuild -list` debe mostrar solo un scheme con destinos macOS.

**Backup**: antes de los cambios, commit `chore: snapshot before removing iOS and visionOS targets` en una rama aparte.

**Verificación**: `xcodebuild -project LiquidNotch.xcodeproj -scheme LiquidNotch -destination 'platform=macOS' build` termina con `BUILD SUCCEEDED`.

### Fase 9 — Limpiar `AppIcon.appiconset/Contents.json`

**Archivo**: `LiquidNotch/Assets.xcassets/AppIcon.appiconset/Contents.json` (modificar).

Eliminar las tres entradas `platform = "ios"` (universal, dark, tinted) y dejar solo las 10 entradas `idiom = "mac"` con sus escalas 1x/2x para tamaños 16/32/128/256/512.

**Verificación**: el JSON parsea correctamente y `xcodebuild` no reporta warning de iconos faltantes.

### Fase 10 — Actualizar `AGENTS.md`

**Archivo**: `AGENTS.md` (modificar).

Cambios:
- "Project" section: de "multi-platform" a "macOS-only".
- "Build & Run" section: solo comando de macOS, eliminar iOS Simulator y visionOS Simulator.
- Agregar: `bundle ID: kelevo.LiquidNotch` (ya está, verificar) y `deployment target: macOS 26.5`.

## Acceptance Criteria

- [ ] Existe `.gitignore` en la raíz con exclusiones para `xcuserdata/`, `*.dmg`, `DerivedData/`, `build/`, `.DS_Store`.
- [ ] Existe `LICENSE` en la raíz con texto MIT y copyright 2026 kelevo.
- [ ] Existe `README.md` con las 15 secciones listadas, badges renderizan.
- [ ] Existe `CONTRIBUTING.md` con flujo de PRs y style guide.
- [ ] Existe `CHANGELOG.md` con entrada `0.1.0`.
- [ ] Existe `.github/workflows/build.yml` con job `build` en `macos-14`.
- [ ] `git ls-files | grep -i "\.dmg"` retorna vacío.
- [ ] `xcodebuild -list -project LiquidNotch.xcodeproj` muestra solo scheme macOS.
- [ ] `AGENTS.md` no menciona iOS ni visionOS.
- [ ] `AppIcon.appiconset/Contents.json` no contiene entradas con `platform = "ios"`.
- [ ] El workflow de GitHub Actions se ejecuta correctamente en el primer push (verificable después del merge).
- [ ] `xcodebuild -project LiquidNotch.xcodeproj -scheme LiquidNotch -destination 'platform=macOS' build` termina con `BUILD SUCCEEDED`.
- [ ] El proyecto se puede clonar en un directorio limpio y compilar siguiendo solo el README.

## Decisiones tomadas

- **Sí: MIT License** — elegido por el usuario. Estándar para proyectos Swift de este tamaño, máxima compatibilidad.
- **No: Apache 2.0** — más pesada, no aporta valor en este proyecto.
- **Sí: GitHub Actions con `macos-14`** — runner Apple Silicon, gratuito para repos públicos.
- **No: Travis CI / CircleCI** — redundante con GitHub Actions.
- **Sí: Eliminar targets iOS y visionOS del `.xcodeproj`** — por decisión del usuario; el proyecto nunca los usó.
- **No: Mantenerlos inactivos** — deuda técnica sin beneficio.
- **Sí: Mover `LiquidNotch.dmg` a GitHub Releases** — hosting de binarios apropiado.
- **No: Mantener el DMG en el repo** — 430KB de binario que se desactualiza con cada commit.
- **Sí: GitHub Actions sube el `.app` como artifact** — facilita pruebas sin clonar.
- **No: Publicar DMG en CI** — fuera de alcance de este spec; se documenta el procedimiento en `CONTRIBUTING.md`.
- **Sí: Eliminar claves iOS del `.pbxproj`** — al borrar los targets, Xcode limpia automáticamente la mayoría. Las `INFOPLIST_KEY_UI*` también se eliminan.
- **No: Mantener Info.plist iOS** — generaría warnings de "build setting unused" en cada build.
- **Sí: README bilingüe (ES + EN)** — el usuario habla español, pero GitHub es global. Secciones en inglés con resumen en español al inicio.

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Eliminar targets iOS rompe `xcodebuild` de forma no obvia | Snapshot pre-cambio en rama separada; verificación con `xcodebuild -list` antes de hacer commit |
| `.gitignore` no excluye un archivo generado nuevo | Revisar `git status` antes de cada commit en las primeras 2 semanas |
| GitHub Actions falla por timeout en runners macOS | `timeout-minutes: 20` y cache de DerivedData (mejora futura, no en este spec) |
| `xcpretty` no instalado en el runner | Usar `xcodebuild ... | xcpretty || xcodebuild ...` como fallback (NO incluido en este spec para mantenerlo simple) |
| README.md tiene info desactualizada cuando se implementen specs futuros | Cada spec que añada feature debe actualizar la sección "Features" del README en el mismo PR |
| Falta de `CODE_OF_CONDUCT.md` | Añadir un placeholder mínimo en `CONTRIBUTING.md` y crear `CODE_OF_CONDUCT.md` basado en Contributor Covenant en un spec futuro (no este) |

## Verification final

```bash
# Verificar exclusiones de git
git ls-files | grep -iE "\.dmg|xcuserdata|DerivedData|\.DS_Store" || echo "OK: nothing ignored wrongly tracked"

# Verificar que solo hay un scheme
xcodebuild -list -project LiquidNotch.xcodeproj | grep -c "^[[:space:]]*LiquidNotch$"  # debe imprimir 1

# Build limpio
xcodebuild -project LiquidNotch.xcodeproj -scheme LiquidNotch -destination 'platform=macOS' clean build

# Verificar contenido del README
grep -c "MIT License" README.md           # >= 1
grep -c "## Build" README.md              # >= 1
grep -c "## Contributing" README.md       # >= 1
```

## What is **NOT** in this spec

- Firma con Developer ID / notarización (específico por usuario, fuera de open source).
- Homebrew tap / Cask submission.
- Sparkle auto-updater.
- Sitio web / docs site.
- App Store submission (incompatible con MediaRemote privado del spec 10).
- Internacionalización del README más allá de español + inglés.
- Code of Conduct formal (placeholder en este spec, real después).
- Tests automatizados (no hay test target, se difiere a un spec dedicado).

Cada uno de esos, si aterriza, va en su propio spec.
