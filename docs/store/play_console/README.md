# Recursos de Google Play — Legend Arrow

Todos los archivos de esta carpeta van en **Play Console → Crecer los usuarios → Presencia en Google Play → Ficha principal de Play Store → Gráficos**. El nombre de cada archivo dice la sección y el campo.

| Archivo | Sección de Play Console | Campo | ¿Obligatorio? |
|---|---|---|---|
| `01_Recursos_visuales_comunes__Icono_de_la_aplicacion__512x512.png` | Recursos visuales comunes | Icono de la aplicación (512×512, PNG de 32 bits, sin transparencia) | Sí |
| `02_Recursos_visuales_comunes__Grafico_de_funciones__1024x500.png` | Recursos visuales comunes | Gráfico de funciones (1024×500, sin alfa) | Sí |
| `03_Recursos_visuales_comunes__Capturas_telefono__01_inicio__1080x1920.png` | Recursos visuales comunes | Capturas de pantalla del teléfono, 1 | Sí (mínimo 2) |
| `03_Recursos_visuales_comunes__Capturas_telefono__02_tutorial__1080x1920.png` | Recursos visuales comunes | Capturas de pantalla del teléfono, 2 | Sí (mínimo 2) |
| `03_Recursos_visuales_comunes__Capturas_telefono__03_puzzle__1080x1920.png` | Recursos visuales comunes | Capturas de pantalla del teléfono, 3 | Recomendado |
| `03_Recursos_visuales_comunes__Capturas_telefono__04_despertar__1080x1920.png` | Recursos visuales comunes | Capturas de pantalla del teléfono, 4 | Recomendado |
| `03_Recursos_visuales_comunes__Capturas_telefono__05_bestiario__1080x1920.png` | Recursos visuales comunes | Capturas de pantalla del teléfono, 5 | Recomendado |
| `03_Recursos_visuales_comunes__Capturas_telefono__06_criatura__1080x1920.png` | Recursos visuales comunes | Capturas de pantalla del teléfono, 6 | Recomendado |
| `04_Recursos_para_tablet__Capturas_7_pulgadas__01_inicio__1200x2133.png` | Recursos para tablet | Capturas de pantalla de tablet de 7 pulgadas, 1 | Opcional (necesario para destacar en tablets) |
| `04_Recursos_para_tablet__Capturas_7_pulgadas__02_puzzle__1200x2133.png` | Recursos para tablet | Capturas de pantalla de tablet de 7 pulgadas, 2 | Opcional |
| `04_Recursos_para_tablet__Capturas_7_pulgadas__03_despertar__1200x2133.png` | Recursos para tablet | Capturas de pantalla de tablet de 7 pulgadas, 3 | Opcional |
| `04_Recursos_para_tablet__Capturas_7_pulgadas__04_bestiario__1200x2133.png` | Recursos para tablet | Capturas de pantalla de tablet de 7 pulgadas, 4 | Opcional |
| `05_Recursos_para_tablet__Capturas_10_pulgadas__01_inicio__1440x2560.png` | Recursos para tablet | Capturas de pantalla de tablet de 10 pulgadas, 1 | Opcional (necesario para destacar en tablets) |
| `05_Recursos_para_tablet__Capturas_10_pulgadas__02_puzzle__1440x2560.png` | Recursos para tablet | Capturas de pantalla de tablet de 10 pulgadas, 2 | Opcional |
| `05_Recursos_para_tablet__Capturas_10_pulgadas__03_despertar__1440x2560.png` | Recursos para tablet | Capturas de pantalla de tablet de 10 pulgadas, 3 | Opcional |
| `05_Recursos_para_tablet__Capturas_10_pulgadas__04_bestiario__1440x2560.png` | Recursos para tablet | Capturas de pantalla de tablet de 10 pulgadas, 4 | Opcional |

Súbelos en el orden de los números: Play muestra las capturas en el orden de subida.

## Qué no se incluye (a propósito)
- **Google Play Games en PC**, **Ordenadores (Chromebook)** y **Android XR**: Legend Arrow no está diseñado para esos dispositivos, así que esas secciones se dejan vacías.
- **Vídeo de vista previa** (URL de YouTube, opcional): no hay vídeo publicado. Existe una grabación real del juego en `docs/media/legend_arrow_gameplay.mp4` si quieres subirla a YouTube.

## Cómo se hicieron
- **Capturas**: fotogramas reales del juego en ejecución (`tools/capture_store.gd`), renderizados por Godot a la resolución de cada dispositivo, no maquetas. Arriba llevan una franja con una frase en inglés, con la tipografía (Inter) y los colores del juego.
  - Teléfono: juego a 1080×1704 + franja de 216 px.
  - Tablet de 7": pantalla de tablet 10:16 (1200×1920) + franja de 213 px.
  - Tablet de 10": pantalla de tablet 10:16 (1440×2304) + franja de 256 px.
  - El juego tiene un único diseño adaptable (no hay un diseño distinto para tablet). En tablet se ve la misma interfaz, algo más ancha.
  - El bestiario completo y los niveles superados se alcanzan con las reglas reales de progresión del juego.
- **Icono**: concepto B (dragón hecho de flechas cortas, una flecha azul pizarra saliendo), `tools/make_icons.py`. Es el mismo dibujo que el icono del lanzador en el teléfono.
- **Gráfico de funciones**: el paisaje del despertar y el Forest Drake renderizados por Godot, con el título "Legend Arrow".

## Regenerar y verificar
```bash
GODOT=/ruta/a/godot tools/make_store_graphics.sh   # vuelve a generar todo y lo verifica
python3 tools/store_assets.py check                 # solo verifica
```
La verificación comprueba que están los 16 archivos con el nombre exacto, que son PNG, el tamaño exacto en píxeles, que no tienen canal alfa (el icono: 32 bits y totalmente opaco) y los límites de peso (icono ≤ 1 MB, gráfico de funciones ≤ 15 MB, capturas ≤ 8 MB). La CI la ejecuta en cada push y publica esta carpeta como el artefacto `play-store-assets`.
