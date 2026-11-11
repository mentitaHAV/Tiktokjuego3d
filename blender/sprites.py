"""
Genera el arte 2.5D del juego con Blender (Workbench, sin antialiasing = pixel art).

Uso (desde D:\\CasaSobrevivientes):
  blender -b -P blender/sprites.py -- personajes   # hojas de los sobrevivientes (24 variantes)
  blender -b -P blender/sprites.py -- zombis       # hojas de los 3 tipos de zombi
  blender -b -P blender/sprites.py -- casa         # casa de muneca: capa trasera y delantera
  blender -b -P blender/sprites.py -- props        # arboles, huertos, barreras, tumba, puerta
  blender -b -P blender/sprites.py -- prueba       # una sola hoja de prueba rapida

Proyeccion (ortografica, elevacion 30 grados, 25 px por metro):
  pantalla_x = X * 25
  pantalla_y = -(Z * cos30 + Y * sin30) * 25          (Y = profundidad, se aleja de la camara)
"""
import bpy, math, os, sys, json
import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALIDA = os.path.join(RAIZ, "arte")
TMP = os.path.join(SALIDA, "_tmp")
os.makedirs(TMP, exist_ok=True)

PPM = 12.5            # pixeles por metro (super pixelado)
ELEV = 35.0           # camara elevada
FRAME = 32            # tamano de cada fotograma de personaje

# ------------------------------------------------------------------ utilidades

def hexc(h):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    # el color de material en Workbench es lineal; convertimos desde sRGB
    f = lambda c: c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (f(r), f(g), f(b), 1.0)


_mats = {}
def mat(h):
    if h not in _mats:
        m = bpy.data.materials.new(h)
        m.diffuse_color = hexc(h)
        _mats[h] = m
    return _mats[h]


def limpiar():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)


def vacio(nombre, loc=(0, 0, 0), padre=None):
    o = bpy.data.objects.new(nombre, None)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    if padre:
        o.parent = padre
    return o


def caja(nombre, tam, loc, color, padre=None, rot=(0, 0, 0)):
    """Caja centrada en loc (relativa al padre) con tamano tam=(x,y,z)."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
    o = bpy.context.active_object
    o.name = nombre
    o.scale = tam
    o.location = loc
    o.rotation_euler = rot
    if padre:
        o.parent = padre
    o.data.materials.append(mat(color))
    return o


def caja_abs(nombre, x0, x1, y0, y1, z0, z1, color):
    return caja(nombre, (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color)


def preparar(res_x, res_y, objetivo):
    """Configura escena, camara ortografica y Workbench sin suavizado. objetivo=(x,y,z) centro de la imagen."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x = res_x
    sc.render.resolution_y = res_y
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.display.render_aa = "OFF"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_object_outline = True
    sh.object_outline_color = (0.04, 0.03, 0.05)
    sh.show_specular_highlight = False
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.exposure = 0.9
    for c in list(bpy.data.cameras):
        bpy.data.cameras.remove(c)
    cd = bpy.data.cameras.new("cam")
    cd.type = "ORTHO"
    cd.ortho_scale = res_x / PPM
    cd.clip_start = 0.1
    cd.clip_end = 200.0
    cam = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(cam)
    e = math.radians(ELEV)
    cam.rotation_euler = (math.radians(90 - ELEV), 0, 0)
    cam.location = (objetivo[0], objetivo[1] - 60 * math.cos(e), objetivo[2] + 60 * math.sin(e))
    sc.camera = cam


def render(ruta):
    bpy.context.scene.render.filepath = ruta
    bpy.ops.render.render(write_still=True)


def ensamblar(rutas, cols, filas, fw, fh, salida):
    """rutas: dict {(fila, col): ruta_png}. Escribe una hoja PNG."""
    hoja = np.zeros((filas * fh, cols * fw, 4), dtype=np.float32)
    for (f, c), ruta in rutas.items():
        img = bpy.data.images.load(ruta)
        img.colorspace_settings.name = "Non-Color"
        img.alpha_mode = "STRAIGHT"
        arr = np.empty(fw * fh * 4, dtype=np.float32)
        img.pixels.foreach_get(arr)
        arr = arr.reshape(fh, fw, 4)
        y0 = (filas - 1 - f) * fh          # las imagenes de Blender van de abajo hacia arriba
        hoja[y0:y0 + fh, c * fw:(c + 1) * fw] = arr
        bpy.data.images.remove(img)
    out = bpy.data.images.new("hoja", cols * fw, filas * fh, alpha=True)
    out.colorspace_settings.name = "Non-Color"
    out.alpha_mode = "STRAIGHT"
    out.pixels.foreach_set(hoja.ravel())
    out.filepath_raw = salida
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)


# ------------------------------------------------------------------ personaje

class Persona:
    """Humanoide de cajas. Mira hacia +X. Pivotes para animar sin armadura."""

    def __init__(self, camisa, pantalon, piel, pelo, zombi=False, escala=1.0, ancho=1.0, gorra=None):
        self.dir = vacio("dir")
        self.raiz = vacio("raiz", padre=self.dir)
        self.cuerpo = vacio("cuerpo", padre=self.raiz)
        s = escala
        self.s = s
        a = ancho
        r = self.cuerpo
        # piernas (pivote en la cadera)
        self.cad_i = vacio("cad_i", (0, 0.11 * a * s, 0.8 * s), r)
        self.cad_d = vacio("cad_d", (0, -0.11 * a * s, 0.8 * s), r)
        for p in (self.cad_i, self.cad_d):
            caja("pierna", (0.17 * a * s, 0.17 * a * s, 0.8 * s), (0, 0, -0.4 * s), pantalon, p)
            caja("bota", (0.24 * s, 0.18 * a * s, 0.1 * s), (0.03 * s, 0, -0.75 * s), "#2a2a2e", p)
        # torso y cabeza
        caja("torso", (0.26 * s, 0.46 * a * s, 0.6 * s), (0, 0, 1.1 * s), camisa, r)
        self.cabeza = vacio("cabeza", (0, 0, 1.4 * s), r)
        caja("cabeza", (0.28 * s, 0.28 * s, 0.28 * s), (0, 0, 0.17 * s), piel, self.cabeza)
        caja("pelo", (0.3 * s, 0.3 * s, 0.1 * s), (-0.01 * s, 0, 0.33 * s), pelo, self.cabeza)
        caja("nuca", (0.1 * s, 0.3 * s, 0.2 * s), (-0.12 * s, 0, 0.2 * s), pelo, self.cabeza)
        if gorra:
            caja("gorra", (0.34 * s, 0.3 * s, 0.07 * s), (0.02 * s, 0, 0.37 * s), gorra, self.cabeza)
            caja("visera", (0.14 * s, 0.3 * s, 0.03 * s), (0.17 * s, 0, 0.35 * s), gorra, self.cabeza)
        if zombi:
            caja("sangre", (0.28 * s, 0.30 * a * s, 0.22 * s), (0.0, 0, 1.18 * s), "#7a0c0c", r)
            caja("sangre2", (0.27 * s, 0.14 * a * s, 0.34 * s), (0.0, 0.14 * a * s, 1.02 * s), "#5a0808", r)
            caja("boca", (0.03 * s, 0.2 * s, 0.07 * s), (0.15 * s, 0, 0.08 * s), "#8a0f0f", self.cabeza)
            caja("ojo", (0.02 * s, 0.05 * s, 0.04 * s), (0.15 * s, 0.07 * s, 0.2 * s), "#d83030", self.cabeza)
            caja("ojo", (0.02 * s, 0.05 * s, 0.04 * s), (0.15 * s, -0.07 * s, 0.2 * s), "#d83030", self.cabeza)
        else:
            caja("ojo", (0.02 * s, 0.04 * s, 0.04 * s), (0.15 * s, 0.07 * s, 0.2 * s), "#15151a", self.cabeza)
            caja("ojo", (0.02 * s, 0.04 * s, 0.04 * s), (0.15 * s, -0.07 * s, 0.2 * s), "#15151a", self.cabeza)
        # brazos (pivote en el hombro)
        self.hom_i = vacio("hom_i", (0, 0.29 * a * s, 1.37 * s), r)
        self.hom_d = vacio("hom_d", (0, -0.29 * a * s, 1.37 * s), r)
        for p in (self.hom_i, self.hom_d):
            caja("brazo", (0.13 * s, 0.13 * a * s, 0.34 * s), (0, 0, -0.17 * s), camisa, p)
            caja("antebrazo", (0.12 * s, 0.12 * a * s, 0.3 * s), (0, 0, -0.49 * s), piel, p)
        self.arma = caja("arma", (0.07 * s, 0.07 * s, 0.3 * s), (0.0, 0, -0.72 * s), "#2b2b30", self.hom_d)
        caja("culata", (0.07 * s, 0.07 * s, 0.1 * s), (0.0, 0, -0.55 * s), "#2b2b30", self.hom_d, rot=(0, 0, 0))
        self.arma.hide_render = True
        self.arma_visible = False
        self.zombi = zombi

    # ---- poses (todas en grados)
    def reset(self):
        for p in (self.cad_i, self.cad_d, self.hom_i, self.hom_d, self.cabeza, self.raiz, self.cuerpo):
            p.rotation_euler = (0, 0, 0)
        self.cuerpo.location = (0, 0, 0)
        self.raiz.location = (0, 0, 0)
        self.arma.hide_render = True

    def girar(self, k):
        self.dir.rotation_euler = (0, 0, math.radians(45 * k))

    def idle(self, t=0.0):
        self.reset()
        self.cuerpo.location = (0, 0, 0.012 * math.sin(2 * math.pi * t))
        if self.zombi:
            self.hom_i.rotation_euler = (0, math.radians(-70), 0)
            self.hom_d.rotation_euler = (0, math.radians(-65), 0)
            self.cabeza.rotation_euler = (0, math.radians(12), 0)
            self.cuerpo.rotation_euler = (0, math.radians(6), 0)

    def caminar(self, t, fuerza=1.0):
        self.reset()
        a = math.sin(2 * math.pi * t)
        sw = 34 * fuerza
        self.cad_i.rotation_euler = (0, math.radians(-sw * a), 0)
        self.cad_d.rotation_euler = (0, math.radians(sw * a), 0)
        self.cuerpo.location = (0, 0, 0.04 * abs(math.cos(2 * math.pi * t)))
        if self.zombi:
            self.hom_i.rotation_euler = (0, math.radians(-75 + 8 * a), 0)
            self.hom_d.rotation_euler = (0, math.radians(-70 - 8 * a), 0)
            self.cabeza.rotation_euler = (0, math.radians(14), math.radians(8 * a))
            self.cuerpo.rotation_euler = (0, math.radians(8), 0)
        else:
            self.hom_i.rotation_euler = (0, math.radians(sw * 0.9 * a), 0)
            self.hom_d.rotation_euler = (0, math.radians(-sw * 0.9 * a), 0)

    def disparar(self, fase):
        self.reset()
        self.arma.hide_render = False
        retro = 0.0 if fase == 0 else 1.0
        self.hom_d.rotation_euler = (0, math.radians(-90 - 9 * retro), 0)
        self.hom_i.rotation_euler = (0, math.radians(-82), 0)
        self.cuerpo.rotation_euler = (0, math.radians(-3 * retro), 0)
        self.cabeza.rotation_euler = (0, math.radians(-4 * retro), 0)
        self.cad_i.rotation_euler = (0, math.radians(12), 0)
        self.cad_d.rotation_euler = (0, math.radians(-14), 0)

    def atacar(self, fase):
        """Zombi: acometida con los dos brazos (fase 0..2)."""
        self.reset()
        v = [(-60, -60, 0), (-115, -112, 8), (-90, -88, 3)][fase]
        self.hom_i.rotation_euler = (0, math.radians(v[0]), 0)
        self.hom_d.rotation_euler = (0, math.radians(v[1]), 0)
        self.cuerpo.rotation_euler = (0, math.radians(14 + v[2]), 0)
        self.cabeza.rotation_euler = (0, math.radians(16), 0)
        self.cad_i.rotation_euler = (0, math.radians(14), 0)
        self.cad_d.rotation_euler = (0, math.radians(-10), 0)

    def morir(self, fase):
        """fase 0..3: cae hacia atras y queda tendido."""
        self.reset()
        ang = [0, 28, 62, 90][fase]
        self.raiz.rotation_euler = (0, math.radians(-ang), 0)
        self.raiz.location = (-0.12 * (ang / 90.0), 0, 0.14 * (ang / 90.0))
        self.hom_i.rotation_euler = (0, math.radians(20 * (ang / 90.0)), 0)
        self.hom_d.rotation_euler = (0, math.radians(-30 * (ang / 90.0)), 0)
        self.cad_i.rotation_euler = (0, math.radians(8 * (ang / 90.0)), 0)


# ------------------------------------------------------------------ hojas de personajes

ANIMS = [("idle", 1), ("walk", 6), ("shoot", 2), ("die", 4)]            # supervivientes
ANIMS_Z = [("idle", 1), ("walk", 6), ("attack", 3), ("die", 4)]         # zombis
DIRS = 8


def columnas(anims):
    out, c = {}, 0
    for nombre, n in anims:
        out[nombre] = [c, n]
        c += n
    return out, c


def hoja_personaje(p, anims, nombre_salida):
    cols_info, ncols = columnas(anims)
    rutas = {}
    for k in range(DIRS):
        p.girar(k)
        c = 0
        for nombre, n in anims:
            for i in range(n):
                t = i / float(n)
                if nombre == "idle":
                    p.idle(0.0)
                elif nombre == "walk":
                    p.caminar(t)
                elif nombre == "shoot":
                    p.disparar(i)
                elif nombre == "attack":
                    p.atacar(i)
                elif nombre == "die":
                    p.morir(i)
                ruta = os.path.join(TMP, "f_%d_%d.png" % (k, c))
                render(ruta)
                rutas[(k, c)] = ruta
                c += 1
    ensamblar(rutas, ncols, DIRS, FRAME, FRAME, os.path.join(SALIDA, nombre_salida))
    return cols_info


def centro_personaje():
    # el centro de la imagen esta a 0.9 m de altura: los pies caen en (32, 51.5) px
    return (0.0, 0.0, 0.9)


CAMISAS = ["#c0392b", "#2980b9", "#27ae60", "#f39c12", "#8e44ad", "#16a085", "#d35400", "#ecf0f1"]
PANTALONES = ["#2f3a5a", "#4a3b2a", "#3a3a40"]
LOOKS = [("#f1c9a0", "#2c1b10"), ("#d19a6a", "#d4a017"), ("#8d5a3b", "#6b3f1d")]


def personajes(solo_prueba=False):
    limpiar()
    preparar(FRAME, FRAME, centro_personaje())
    info = None
    lista = [(0, 0)] if solo_prueba else [(c, l) for l in range(len(LOOKS)) for c in range(len(CAMISAS))]
    for ci, li in lista:
        for o in list(bpy.data.objects):
            if o.type != "CAMERA":
                bpy.data.objects.remove(o, do_unlink=True)
        piel, pelo = LOOKS[li]
        p = Persona(CAMISAS[ci], PANTALONES[(ci + li) % len(PANTALONES)], piel, pelo,
                    gorra=("#222831" if (ci + li) % 4 == 0 else None))
        info = hoja_personaje(p, ANIMS, "sobreviviente_c%d_l%d.png" % (ci, li))
        print("hoja", ci, li, flush=True)
    meta = {"frame": FRAME, "dirs": DIRS, "anims": info, "pie": [FRAME / 2, FRAME / 2 + 0.9 * math.cos(math.radians(ELEV)) * PPM], "camisas": len(CAMISAS), "looks": len(LOOKS)}
    json.dump(meta, open(os.path.join(SALIDA, "sobreviviente.json"), "w"), indent=2)


def zombis():
    limpiar()
    preparar(FRAME, FRAME, centro_personaje())
    tipos = {
        "normal": dict(camisa="#5a4a6a", pantalon="#3a3a42", piel="#6fae5a", pelo="#2a2a22", escala=1.0, ancho=1.0),
        "corredor": dict(camisa="#8a3030", pantalon="#4a4a30", piel="#9ab85a", pelo="#3a3020", escala=0.95, ancho=0.85),
        "bruto": dict(camisa="#3a3a3a", pantalon="#26262a", piel="#4f8a46", pelo="#1a1a14", escala=1.3, ancho=1.35),
    }
    info = None
    for nombre, kw in tipos.items():
        for o in list(bpy.data.objects):
            if o.type != "CAMERA":
                bpy.data.objects.remove(o, do_unlink=True)
        p = Persona(zombi=True, **kw)
        info = hoja_personaje(p, ANIMS_Z, "zombi_%s.png" % nombre)
        print("zombi", nombre, flush=True)
    meta = {"frame": FRAME, "dirs": DIRS, "anims": info, "pie": [FRAME / 2, FRAME / 2 + 0.9 * math.cos(math.radians(ELEV)) * PPM]}
    json.dump(meta, open(os.path.join(SALIDA, "zombi.json"), "w"), indent=2)


# ------------------------------------------------------------------ la casa (muneca) y props
# Coordenadas de la casa en metros: X 0..12, Y 0..5 (frente en Y=0), Z 0..6.4
# El tamano de imagen y el origen se guardan en casa.json para que Godot alinee todo.

CASA_W, CASA_D, CASA_H = 12.0, 5.0, 6.4
PISO2 = 3.2
IMG_W, IMG_H = 210, 140
OX, OY = 15, 20


def centro_casa():
    # queremos X=0 en el pixel 30 -> centro de imagen en X = (IMG_W/2 - 30)/PPM
    cx = (IMG_W / 2 - 30) / PPM
    # el suelo frontal (Y=0,Z=0) cerca de la parte baja: pixel y = IMG_H-40 -> centro z/y combinados
    # pantalla_y relativa al centro = -(dz*cos + dy*sin)*PPM ; usamos objetivo (cx, 0, zc)
    # queremos que (Y=0,Z=0) caiga en IMG_H-40 -> -(0 - zc)*cos*PPM = (IMG_H-40) - IMG_H/2
    zc = ((IMG_H - 40) - IMG_H / 2) / (math.cos(math.radians(ELEV)) * PPM)
    return (cx, 0.0, -zc * -1.0 if False else zc * -1.0 * -1.0)


def construir_casa_atras():
    # suelos
    caja_abs("suelo0", -0.3, 12.3, 0, CASA_D, -0.25, 0.0, "#9b6a3a")
    caja_abs("suelo0b", -0.3, 12.3, 0, CASA_D, -0.02, 0.0, "#b07d45")
    # planta alta con hueco de escalera (X 7..9.4)
    caja_abs("suelo1a", -0.3, 7.0, 0, CASA_D, PISO2 - 0.22, PISO2, "#8a5c30")
    caja_abs("suelo1b", 9.4, 12.3, 0, CASA_D, PISO2 - 0.22, PISO2, "#8a5c30")
    caja_abs("suelo1c", 7.0, 9.4, 0, 1.6, PISO2 - 0.22, PISO2, "#8a5c30")
    # pared del fondo (dos pisos con distinto color)
    caja_abs("fondo0", -0.3, 12.3, CASA_D - 0.25, CASA_D, 0, PISO2 - 0.22, "#d9b98a")
    caja_abs("fondo1", -0.3, 12.3, CASA_D - 0.25, CASA_D, PISO2, CASA_H, "#c9a979")
    caja_abs("zocalo0", -0.3, 12.3, CASA_D - 0.3, CASA_D - 0.22, 0, 0.35, "#7a5230")
    caja_abs("zocalo1", -0.3, 12.3, CASA_D - 0.3, CASA_D - 0.22, PISO2, PISO2 + 0.35, "#7a5230")
    # ventanas en el fondo
    for x in (1.2, 3.4, 8.6, 10.2):
        for z0 in (1.3, PISO2 + 1.3):
            caja_abs("vent", x, x + 1.1, CASA_D - 0.3, CASA_D - 0.22, z0, z0 + 1.1, "#bfe8ff")
            caja_abs("marco", x - 0.08, x + 1.18, CASA_D - 0.27, CASA_D - 0.22, z0 - 0.08, z0 + 1.18, "#5a3a1e")
    # paredes laterales (gruesas, se ven como columnas con ventana tapiada)
    for x0, x1 in ((-0.55, -0.1), (12.1, 12.55)):
        caja_abs("lat", x0, x1, 0, CASA_D, 0, CASA_H, "#6e4a2a")
    # techo plano que asoma por detras de la pared del fondo
    caja_abs("techo", -0.8, 12.8, CASA_D - 0.4, CASA_D + 2.2, CASA_H, CASA_H + 0.35, "#a63a3a")
    caja_abs("alero", -0.8, 12.8, CASA_D - 0.5, CASA_D - 0.3, CASA_H - 0.15, CASA_H + 0.35, "#6e2424")
    # escalera (sube de X=7 a X=9.4 pegada al fondo)
    n = 12
    for i in range(n):
        x0 = 7.0 + i * (2.4 / n)
        h = (i + 1) * (PISO2 / n)
        caja_abs("peldano", x0, x0 + 2.4 / n, 3.4, CASA_D - 0.25, 0, h, "#a8763f")
    # cocina
    caja_abs("cocina", 0.6, 2.2, 3.6, 4.75, 0, 0.95, "#4a4a52")
    caja_abs("cocina_top", 0.55, 2.25, 3.55, 4.8, 0.95, 1.05, "#7a7a86")
    caja_abs("campana", 0.7, 2.1, 4.3, 4.75, 2.0, 2.6, "#5a5a64")
    # mesa y sillas
    caja_abs("mesa", 3.6, 5.6, 2.2, 3.4, 0.8, 0.92, "#9b6a3a")
    for x, y in ((3.7, 2.3), (5.4, 2.3), (3.7, 3.2), (5.4, 3.2)):
        caja_abs("pata", x, x + 0.1, y, y + 0.1, 0, 0.8, "#6e4a2a")
    # estante de comida
    caja_abs("estante", 5.0, 6.6, 4.4, 4.75, 0.0, 2.2, "#7a5230")
    for z in (0.9, 1.5, 2.1):
        caja_abs("balda", 4.95, 6.65, 4.3, 4.75, z - 0.04, z + 0.04, "#a8763f")
    for i, c in enumerate(("#e8a33c", "#c0392b", "#6fae5a", "#e8a33c", "#c0392b", "#6fae5a")):
        caja_abs("comida", 5.1 + (i % 3) * 0.5, 5.4 + (i % 3) * 0.5, 4.4, 4.7, 0.95 + (i // 3) * 0.6, 1.3 + (i // 3) * 0.6, c)
    # banco de trabajo con tablas
    caja_abs("banco", 9.9, 11.7, 3.6, 4.7, 0.0, 0.95, "#8a5f35")
    caja_abs("banco_top", 9.85, 11.75, 3.55, 4.75, 0.9, 1.0, "#b07d45")
    for i in range(4):
        caja_abs("tabla", 10.0, 11.5, 3.7, 3.95, 1.0 + i * 0.07, 1.07 + i * 0.07, "#d2a96a")
    # caja de municion y armero
    caja_abs("armero", 8.6, 9.3, 4.1, 4.75, 0, 1.4, "#4b5320")
    caja_abs("armero2", 8.6, 9.3, 4.1, 4.2, 0.6, 1.0, "#6b7430")
    # camas planta alta (6)
    xs = [0.5, 2.5, 4.5, 9.7, 11.0 - 0.1]
    camas = [0.6, 2.6, 4.6, 9.7]
    for x in camas:
        caja_abs("cama", x, x + 1.7, 3.0, 4.8, PISO2, PISO2 + 0.35, "#5a6ea8")
        caja_abs("almohada", x + 0.05, x + 0.55, 4.1, 4.75, PISO2 + 0.35, PISO2 + 0.5, "#eaeaea")
        caja_abs("manta", x + 0.6, x + 1.7, 3.0, 4.8, PISO2 + 0.35, PISO2 + 0.42, "#3f4f86")
    # lampara
    caja_abs("lampara", 5.9, 6.1, 2.4, 2.6, 2.6, 3.0, "#f4e29a")
    caja_abs("lampara2", 5.9, 6.1, 2.4, 2.6, PISO2 + 2.6, PISO2 + 3.0, "#f4e29a")


def construir_casa_delante():
    # muro bajo frontal con hueco para la puerta (X 5.3..6.7) y barandilla en la planta alta
    for x0, x1 in ((-0.55, 5.3), (6.7, 12.55)):
        caja_abs("muro", x0, x1, -0.05, 0.25, 0, 0.5, "#8a6a4a")
        caja_abs("muro_top", x0, x1, -0.1, 0.3, 0.5, 0.6, "#6e4a2a")
    caja_abs("pilar_i", -0.6, 0.0, -0.1, 0.35, 0, CASA_H, "#5b3a1f")
    caja_abs("pilar_d", 12.0, 12.6, -0.1, 0.35, 0, CASA_H, "#5b3a1f")
    caja_abs("marco_p1", 5.2, 5.4, -0.1, 0.3, 0, 2.3, "#5b3a1f")
    caja_abs("marco_p2", 6.6, 6.8, -0.1, 0.3, 0, 2.3, "#5b3a1f")
    caja_abs("dintel", 5.2, 6.8, -0.1, 0.3, 2.3, 2.5, "#5b3a1f")
    # barandilla
    caja_abs("baranda", 0.0, 12.0, -0.05, 0.1, PISO2 + 0.6, PISO2 + 0.7, "#6e4a2a")
    caja_abs("baranda_b", 0.0, 12.0, -0.05, 0.1, PISO2 + 0.15, PISO2 + 0.22, "#6e4a2a")
    for i in range(0, 25):
        x = i * 0.5
        caja_abs("barrote", x, x + 0.08, -0.04, 0.08, PISO2, PISO2 + 0.65, "#8a6a4a")
    # frente de la losa de la planta alta
    caja_abs("losa_frente", -0.6, 12.6, -0.1, 0.3, PISO2 - 0.3, PISO2, "#6e4a2a")
    # ventanas bajas con rejilla (a los lados de la puerta)
    for x in (1.2, 3.2, 8.2, 10.2):
        caja_abs("reja", x, x + 1.2, -0.08, 0.0, 0.5, 0.9, "#3a2a1a")


def casa():
    objetivo = (((IMG_W / 2 - OX) / PPM), 0.0, 0.0)
    # El centro de la imagen en pantalla corresponde al punto objetivo; ajustamos Z/Y para que
    # (Y=0,Z=0) quede 40 px por encima del borde inferior: desplazamos el objetivo hacia arriba.
    ofs = (IMG_H / 2 - OY) / PPM                 # metros de pantalla por debajo del centro
    # elegimos mover el objetivo en Z: pantalla_y = -(dz*cos)*PPM -> dz = -ofs/cos
    objetivo = (objetivo[0], 0.0, ofs / math.cos(math.radians(ELEV)))
    for nombre, f in (("casa_atras.png", construir_casa_atras), ("casa_delante.png", construir_casa_delante)):
        limpiar()
        preparar(IMG_W, IMG_H, objetivo)
        f()
        render(os.path.join(SALIDA, nombre))
        print("casa", nombre, flush=True)
    meta = {
        "ppm": PPM, "elev": ELEV, "img": [IMG_W, IMG_H], "ancho": CASA_W, "fondo": CASA_D, "alto": CASA_H, "piso2": PISO2,
        "origen_px": [float(OX), float(IMG_H - OY)],      # donde cae (X=0,Y=0,Z=0)
        "puerta": [5.3, 6.7], "escalera": [7.0, 9.4],
    }
    json.dump(meta, open(os.path.join(SALIDA, "casa.json"), "w"), indent=2)


def props():
    defs = {}
    # (nombre, ancho_px, alto_px, constructor, pie_px)
    def arbol(vivo):
        caja_abs("tronco", -0.25, 0.25, -0.25, 0.25, 0, 2.6 if vivo else 0.5, "#5a3a1e")
        if vivo:
            caja_abs("copa1", -1.3, 1.3, -1.3, 1.3, 2.4, 3.6, "#2f7d3a")
            caja_abs("copa2", -0.9, 0.9, -0.9, 0.9, 3.5, 4.5, "#3a9a47")
            caja_abs("copa3", -0.5, 0.5, -0.5, 0.5, 4.4, 5.1, "#4bb35a")
    def huerto(listo):
        caja_abs("tierra", -0.7, 0.7, -0.5, 0.5, 0, 0.18, "#3d2a1b")
        for i in range(3):
            x = -0.45 + i * 0.45
            if listo:
                caja_abs("tallo", x - 0.05, x + 0.05, -0.05, 0.05, 0.18, 0.7, "#5fd35f")
                caja_abs("hoja", x - 0.18, x + 0.18, -0.04, 0.04, 0.45, 0.55, "#7fe07f")
                caja_abs("fruto", x - 0.1, x + 0.1, -0.1, 0.1, 0.7, 0.9, "#e8453c")
            else:
                caja_abs("brote", x - 0.04, x + 0.04, -0.04, 0.04, 0.18, 0.3, "#5fd35f")
    def valla(estado):
        # estado 0 entera, 1 danada, 2 casi rota
        h = [1.3, 1.1, 0.7][estado]
        for i in range(5):
            x = -0.9 + i * 0.45
            caja_abs("poste", x - 0.09, x + 0.09, -0.09, 0.09, 0, h + (0.12 if i % 2 == 0 else 0), "#8b5a2b")
        for z in ([0.35, 0.8], [0.3, 0.7], [0.25])[estado]:
            ang = 0.0 if estado == 0 else (0.05 if estado == 1 else 0.18)
            caja("travesano", (1.9, 0.12, 0.16), (0, 0.04, z), "#a97a3c", rot=(0, ang, 0))
        if estado == 2:
            caja("rota", (0.7, 0.1, 0.12), (0.55, 0.0, 0.07), "#6b4520", rot=(0, 0.1, 0.2))
    def tumba():
        caja_abs("base", -0.35, 0.35, -0.2, 0.2, 0, 0.12, "#7e848a")
        caja_abs("lapida", -0.28, 0.28, -0.1, 0.1, 0.12, 0.95, "#9aa0a6")
        caja_abs("cruz_v", -0.05, 0.05, -0.12, -0.08, 0.35, 0.85, "#5a5f66")
        caja_abs("cruz_h", -0.18, 0.18, -0.12, -0.08, 0.6, 0.7, "#5a5f66")
    def puerta(estado):
        h = [2.2, 2.0, 1.3, 0.3][estado]
        caja_abs("hoja", -0.65, 0.65, -0.08, 0.08, 0, h, "#7a4b22")
        if estado < 3:
            caja_abs("tabla1", -0.6, 0.6, -0.12, -0.08, 0.5, 0.75, "#a97a3c")
            caja_abs("tabla2", -0.6, 0.6, -0.12, -0.08, 1.2, 1.45, "#a97a3c")
            caja_abs("pomo", 0.4, 0.5, -0.12, -0.08, 1.0, 1.1, "#e0c060")
    lista = [
        ("arbol", 64, 80, lambda: arbol(True)), ("tocon", 32, 32, lambda: arbol(False)),
        ("huerto_listo", 32, 32, lambda: huerto(True)), ("huerto_vacio", 32, 32, lambda: huerto(False)),
        ("valla_0", 48, 48, lambda: valla(0)), ("valla_1", 48, 48, lambda: valla(1)), ("valla_2", 48, 48, lambda: valla(2)),
        ("tumba", 32, 32, tumba),
        ("puerta_0", 48, 48, lambda: puerta(0)), ("puerta_1", 48, 48, lambda: puerta(1)),
        ("puerta_2", 48, 48, lambda: puerta(2)), ("puerta_3", 48, 48, lambda: puerta(3)),
    ]
    meta = {}
    for nombre, w, h, f in lista:
        limpiar()
        # pie del objeto (Y=0,Z=0) a 12 px del borde inferior
        ofs = (h / 2 - 6) / PPM
        preparar(w, h, (0.0, 0.0, ofs / math.cos(math.radians(ELEV))))
        f()
        render(os.path.join(SALIDA, "prop_%s.png" % nombre))
        meta[nombre] = {"w": w, "h": h, "pie": [w / 2.0, h - 6.0]}
        print("prop", nombre, flush=True)
    json.dump(meta, open(os.path.join(SALIDA, "props.json"), "w"), indent=2)



# ------------------------------------------------------------------ fondo postapocaliptico y escenario

import random

def edificio(rng, x, ancho, alto, col, col_vent, ruinas=True, verde=True):
    caja_abs("edif", x, x + ancho, 0, 6, 0, alto, col)
    # ventanas en rejilla
    nx = max(1, int(ancho / 2.0))
    nz = max(1, int(alto / 2.6))
    for i in range(nx):
        for j in range(nz):
            if rng.random() < 0.8:
                vx = x + 0.6 + i * (ancho - 1.2) / nx
                vz = 1.0 + j * 2.6
                if vz + 1.3 < alto:
                    c = col_vent if rng.random() < 0.9 else "#d99a3a"
                    caja_abs("vent", vx, vx + 0.9, -0.1, 0.0, vz, vz + 1.3, c)
    if ruinas and rng.random() < 0.6:       # azotea rota
        caja_abs("roto", x + ancho * 0.45, x + ancho + 0.1, -0.2, 6, alto - 1.4, alto + 0.01, "#00000000")
    if verde:
        for k in range(rng.randint(2, 5)):
            vx = x + rng.random() * (ancho - 1.0)
            vz = alto - rng.random() * alto * 0.7
            caja_abs("hiedra", vx, vx + 0.9 + rng.random() * 1.2, -0.25, -0.05, vz, vz + 0.8 + rng.random() * 1.5, "#4f7a4a")


def fondo():
    W, H = 320, 130
    capas = [
        ("fondo_lejos", "#9fb3a9", "#7d948a", 12, 22, 6.0, 0.4),
        ("fondo_medio", "#7b9187", "#4f655b", 9, 16, 6.0, 0.6),
    ]
    rng = random.Random(11)
    for nombre, col, vent, hmin, hmax, wmin, k in capas:
        limpiar()
        # k > 1 = capa mas lejana (se ve mas pequena); el suelo queda 20 px sobre el borde inferior
        ppm = PPM * k
        preparar(W, H, ((W / 2) / ppm, 0.0, (H / 2 - 10) / (math.cos(math.radians(ELEV)) * ppm)))
        bpy.data.objects["cam"].data.ortho_scale = W / ppm
        x = -2.0
        while x < W / ppm + 4:
            w = rng.uniform(wmin, wmin + 4.0)
            h = rng.uniform(hmin, hmax)
            edificio(rng, x, w, h, col, vent, ruinas=False)
            x += w + rng.uniform(-0.6, 1.2)
        render(os.path.join(SALIDA, nombre + ".png"))
        print("fondo", nombre, flush=True)
    # primer plano: hierba alta y maleza (se dibuja delante de todo)
    limpiar()
    W2, H2 = 320, 45
    preparar(W2, H2, ((W2 / 2) / PPM, 0.0, (H2 / 2 - 3) / (math.cos(math.radians(ELEV)) * PPM)))
    for i in range(140):
        x = rng.uniform(-0.5, W2 / PPM + 0.5)
        h = rng.uniform(0.5, 1.9)
        c = rng.choice(["#2f4a36", "#3a5a40", "#264030", "#4a6a48"])
        caja_abs("hierba", x, x + 0.1, -0.5, -0.4, 0, h, c)
        if rng.random() < 0.25:
            caja_abs("hierba", x - 0.2, x + 0.3, -0.5, -0.4, 0, h * 0.5, c)
    render(os.path.join(SALIDA, "primer_plano.png"))
    # suelo: tierra y hierba (franja)
    limpiar()
    preparar(640, 80, (12.8, 0.0, (40 - 28) / (math.cos(math.radians(ELEV)) * PPM)))
    caja_abs("tierra", -1, 27, -6, 2, -3.0, 0, "#5a4a38")
    caja_abs("cesped", -1, 27, -6, 2, -0.1, 0.0, "#5f7d4a")
    r2 = random.Random(5)
    for i in range(120):
        x = r2.uniform(0, 25.5)
        caja_abs("piedra", x, x + 0.25, -5.5, -5.2, -r2.uniform(0.2, 2.5), -0.05, "#6a5a46")
    render(os.path.join(SALIDA, "suelo.png"))
    print("suelo", flush=True)


def furgoneta():
    # furgoneta abandonada (cobertura en el patio), mirando a la izquierda
    limpiar()
    w, h = 80, 45
    preparar(w, h, (0.0, 0.0, (h / 2 - 4) / (math.cos(math.radians(ELEV)) * PPM)))
    caja_abs("chasis", -2.6, 2.6, -0.9, 0.9, 0.35, 1.5, "#d8d8cc")
    caja_abs("cabina", -2.6, -0.9, -0.88, 0.88, 1.5, 2.2, "#c9c9bd")
    caja_abs("carga", -0.9, 2.6, -0.88, 0.88, 1.5, 2.35, "#d8d8cc")
    caja_abs("parabrisas", -2.62, -1.2, -0.9, 0.9, 1.55, 2.1, "#7aa0a8")
    caja_abs("franja", -2.6, 2.6, -0.92, 0.92, 0.9, 1.1, "#7a2a2a")
    caja_abs("oxido", 0.5, 1.8, -0.93, -0.88, 0.4, 1.2, "#8a5a3a")
    for x in (-1.6, 1.6):
        caja_abs("rueda", x - 0.45, x + 0.45, -1.0, 1.0, 0, 0.9, "#26262a")
    for x in (-2.1, 0.2, 2.0):
        caja_abs("hierba", x, x + 0.5, -1.0, -0.9, 0, 0.7, "#3a5a40")
    render(os.path.join(SALIDA, "prop_furgoneta.png"))
    json.dump({"w": w, "h": h, "pie": [w / 2.0, h - 4.0]}, open(os.path.join(SALIDA, "furgoneta.json"), "w"))
    print("furgoneta", flush=True)


if __name__ == "__main__":
    modo = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "prueba"
    if modo == "personajes":
        personajes()
    elif modo == "zombis":
        zombis()
    elif modo == "casa":
        casa()
    elif modo == "props":
        props()
    elif modo == "fondo":
        fondo()
        furgoneta()
    else:
        personajes(solo_prueba=True)
