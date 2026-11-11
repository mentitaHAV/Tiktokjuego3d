# Casa de Sobrevivientes (Tiktokjuego3d)

Pecera para streams de TikTok: cada donador es un sobreviviente que vive en una casa de 2 plantas.
Rosa = aparece una persona; la misma persona manda otra rosa = reparte suministros; GG = invoca zombis.
Si mueren todos, cambia la generacion y se empieza de cero.

- Motor: Godot 4.7 (abrir con `ABRIR_CASA.bat` o `godot --path .`)
- Arte 2.5D pixelado: generado con Blender 5.2 (`blender -b -P blender/sprites.py -- personajes|zombis|casa|props|fondo`), ya incluido en `arte/`
- Simulacion: `scripts/sim.gd`  | Dibujo y gore: `scripts/vista.gd`  | Prueba sin pantalla: `tests/prueba.gd`
- Donaciones: una linea JSON por evento en `eventos.jsonl`, p. ej. `{"usuario":"ana","regalo":"Rose","cantidad":1}`
- Teclas de prueba: R rosa nueva, T rosa de Tester, G GG, 1-4 velocidad, espacio pausa
