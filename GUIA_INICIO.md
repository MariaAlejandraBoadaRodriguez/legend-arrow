# Guía rápida — arrancar Legend Arrow en Claude Code

## 1. Crear el repo en GitHub
- github.com → **NEW** repository
- Nombre: **legend-arrow** · Visibilidad: **PRIVATE** · NO marques "Add README" (ya viene en el kit)
- Clic **CREATE REPOSITORY**

## 2. Subir el kit
- En la página del repo vacío: **UPLOADING AN EXISTING FILE**
- Descomprime `legend-arrow-kit.zip` y arrastra **TODO EL CONTENIDO** de la carpeta `legend-arrow/` (incluye `.gitignore`; si el navegador lo oculta, súbelo después con "Add file")
- Mensaje: `chore: add design inputs and Claude instructions` → **COMMIT CHANGES**

## 3. Abrir Claude Code
- claude.ai/code → selecciona el repo **legend-arrow** → nueva sesión
- Si te pregunta por permisos de red/entorno: elige **TRUSTED / FULL NETWORK** (necesita descargar Godot, Android SDK y Gradle)

## 4. Primera sesión
- Copia y pega el bloque de `docs/prompts/01_KICKOFF.md`
- Déjalo trabajar. Al terminar te da: PASS/FAIL/BLOCKED, SHA y link de Actions

## 5. Sesiones siguientes (igual que con Qubit Rush)
- Siempre pega `docs/prompts/02_CONTINUE.md` → retoma desde `docs/PROGRESS.md`
- Si Actions sale en rojo → pega **PROMPT 3 (Fix CI)**
- Cuando llegue a M5/M6 → pega **PROMPT 4 (Final tests)**

## 6. Probar en tu computador
- Descarga el APK desde la pestaña **ACTIONS** → último run verde → Artifacts
- Android Studio → Device Manager → arranca el emulador → **ARRASTRA EL APK** a la ventana del emulador

## Orden de hitos
M0 auditoría + CI · M1 motor del puzzle + tests · M2 slice jugable (APK) · M3 anuncios/consentimiento · M4 24 niveles + 12 criaturas · M5 tests E2E en emulador · M6 AAB + QA_REPORT + checklist de publicación
