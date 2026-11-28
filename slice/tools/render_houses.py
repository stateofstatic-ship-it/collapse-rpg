#!/usr/bin/env python3
"""Render the street's houses from 3D models into game sprites.

Blender as a Python module (pip install bpy), Cycles on the CPU, procedural
materials (lap siding, asphalt shingles, brick, trim, glass). The camera matches
the game's 2:1 tile angle (a 1 x 1 tile is 128 x 64 px, a person about 100 px).

Each look is a 5 x 4 ranch house whose garage, front door and big window face
model +X (grid +y, south). Turn t spins the model a quarter turn clockwise on
screen; the game draws turn (facing + map turn) % 4. Every PNG is 640 x 512
with the front-most footprint cell's centre at pixel (352, 460) for even turns
(5 x 4 on screen) and (288, 460) for odd turns (4 x 5 on screen).

Writes assets/houses/h<look>_<turn>.png.
Run: python3 tools/render_houses.py [samples] [look ...]
"""
import math
import os
import sys

import bpy
from mathutils import Euler, Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "houses")
SAMPLES = int(sys.argv[1]) if len(sys.argv) > 1 and __name__ == "__main__" else 32
ONLY = [int(a) for a in sys.argv[2:]] if __name__ == "__main__" else []
os.makedirs(OUT, exist_ok=True)

PX_PER_UNIT = 128 / math.sqrt(2)          # horizontal pixels per tile edge
UNIT_Z = 112 / (PX_PER_UNIT * math.sin(math.radians(60)))  # wall height in tiles (112 px)
W_PX, H_PX = 640, 512

# Grid x maps to Blender +Y, grid y to Blender +X, so +x runs down-right on screen.
NU, NV = 5.0, 4.0           # footprint along grid x and grid y
WALL = UNIT_Z
RISE = 96 / (PX_PER_UNIT * math.sin(math.radians(60)))
OV = 0.25

# footprint in Blender coords (anchor front cell centre at the origin)
X0, X1 = 0.5 - NV, 0.5
Y0, Y1 = 0.5 - NU, 0.5
CX, CY = (X0 + X1) / 2, (Y0 + Y1) / 2


# ------------------------------------------------------------------ materials
def nodes_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    return m, nt, bsdf


def coord(nt, a, b, sa, sb):
    """Vector made from two object-space axes, scaled."""
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    ma = nt.nodes.new("ShaderNodeMath"); ma.operation = "MULTIPLY"; ma.inputs[1].default_value = sa
    mb = nt.nodes.new("ShaderNodeMath"); mb.operation = "MULTIPLY"; mb.inputs[1].default_value = sb
    nt.links.new(sep.outputs[a], ma.inputs[0])
    nt.links.new(sep.outputs[b], mb.inputs[0])
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(ma.outputs[0], comb.inputs[0])
    nt.links.new(mb.outputs[0], comb.inputs[1])
    return comb.outputs[0]


def siding(name, col):
    m, nt, b = nodes_mat(name)
    # horizontal lap boards: a sawtooth along Z gives each board a lip
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; mul.inputs[1].default_value = 9.0
    nt.links.new(sep.outputs["Z"], mul.inputs[0])
    fr = nt.nodes.new("ShaderNodeMath"); fr.operation = "FRACT"
    nt.links.new(mul.outputs[0], fr.inputs[0])
    bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.6; bump.inputs["Distance"].default_value = 0.02
    nt.links.new(fr.outputs[0], bump.inputs["Height"])
    nt.links.new(bump.outputs[0], b.inputs["Normal"])
    noise = nt.nodes.new("ShaderNodeTexNoise"); noise.inputs["Scale"].default_value = 30
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = [c * 0.9 for c in col] + [1]
    ramp.color_ramp.elements[1].color = list(col) + [1]
    nt.links.new(noise.outputs[0], ramp.inputs[0])
    shade = nt.nodes.new("ShaderNodeMix"); shade.data_type = "RGBA"; shade.blend_type = "MULTIPLY"
    shade.inputs[0].default_value = 0.25
    nt.links.new(ramp.outputs[0], shade.inputs[6])
    nt.links.new(fr.outputs[0], shade.inputs[7])
    nt.links.new(shade.outputs[2], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.7
    return m


def shingles(name, col, along="Y"):
    m, nt, b = nodes_mat(name)
    brick = nt.nodes.new("ShaderNodeTexBrick")
    brick.inputs["Scale"].default_value = 1.0
    brick.inputs["Mortar Size"].default_value = 0.012
    brick.inputs["Brick Width"].default_value = 0.34
    brick.inputs["Row Height"].default_value = 0.11
    brick.inputs["Color1"].default_value = list(col) + [1]
    brick.inputs["Color2"].default_value = [c * 0.78 for c in col] + [1]
    brick.inputs["Mortar"].default_value = [c * 0.45 for c in col] + [1]
    nt.links.new(coord(nt, along, "Z", 1.0, 1.0), brick.inputs["Vector"])
    noise = nt.nodes.new("ShaderNodeTexNoise"); noise.inputs["Scale"].default_value = 60
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "OVERLAY"
    mix.inputs[0].default_value = 0.35
    nt.links.new(brick.outputs["Color"], mix.inputs[6])
    nt.links.new(noise.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], b.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.8; bump.inputs["Distance"].default_value = 0.02
    nt.links.new(brick.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs[0], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = 0.9
    return m


def brick(name):
    m, nt, b = nodes_mat(name)
    br = nt.nodes.new("ShaderNodeTexBrick")
    br.inputs["Scale"].default_value = 1.0
    br.inputs["Brick Width"].default_value = 0.16
    br.inputs["Row Height"].default_value = 0.055
    br.inputs["Mortar Size"].default_value = 0.008
    br.inputs["Color1"].default_value = (0.42, 0.16, 0.11, 1)
    br.inputs["Color2"].default_value = (0.33, 0.12, 0.09, 1)
    br.inputs["Mortar"].default_value = (0.55, 0.52, 0.48, 1)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    add = nt.nodes.new("ShaderNodeMath"); add.operation = "ADD"
    nt.links.new(sep.outputs["X"], add.inputs[0]); nt.links.new(sep.outputs["Y"], add.inputs[1])
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(add.outputs[0], comb.inputs[0]); nt.links.new(sep.outputs["Z"], comb.inputs[1])
    nt.links.new(comb.outputs[0], br.inputs["Vector"])
    nt.links.new(br.outputs["Color"], b.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.5
    nt.links.new(br.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs[0], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = 0.85
    return m


def flat(name, col, rough=0.6, metal=0.0):
    m, nt, b = nodes_mat(name)
    b.inputs["Base Color"].default_value = list(col) + [1]
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def glass(name):
    m, nt, b = nodes_mat(name)
    b.inputs["Base Color"].default_value = (0.05, 0.08, 0.11, 1)
    b.inputs["Roughness"].default_value = 0.08
    b.inputs["Specular IOR Level"].default_value = 0.9
    return m


# ------------------------------------------------------------------ geometry
def box(name, x0, x1, y0, y1, z0, z1, mat):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.name = name
    o.scale = ((x1 - x0), (y1 - y0), (z1 - z0))
    o.location = ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    bpy.ops.object.transform_apply(scale=True, location=False)
    o.data.materials.append(mat)
    return o


def mesh(name, verts, faces, mat, solidify=0.0):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    if solidify:
        mod = o.modifiers.new("s", "SOLIDIFY")
        mod.thickness = solidify
    return o



LOOKS = [
    # siding, roof, door/shutter, roof style
    ((0.42, 0.5, 0.36), (0.17, 0.17, 0.19), (0.38, 0.07, 0.06), "gable"),
    ((0.33, 0.42, 0.52), (0.24, 0.19, 0.15), (0.1, 0.16, 0.3), "hip"),
    ((0.66, 0.58, 0.42), (0.2, 0.21, 0.24), (0.12, 0.26, 0.16), "gable"),
    ((0.82, 0.8, 0.74), (0.14, 0.15, 0.15), (0.5, 0.34, 0.1), "hip"),
    ((0.5, 0.24, 0.19), (0.26, 0.24, 0.22), (0.1, 0.1, 0.11), "gable"),
    ((0.36, 0.38, 0.4), (0.2, 0.17, 0.16), (0.36, 0.1, 0.22), "hip"),
]


def new_scene(w_px=W_PX, h_px=H_PX):
    global scene
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.resolution_x, scene.render.resolution_y = w_px, h_px
    scene.view_settings.view_transform = "Standard"

    return scene


def build(look):
    side_c, roof_c, door_c, style = LOOKS[look]
    SIDE = siding("siding", side_c)
    ROOF = shingles("roof", roof_c)
    ROOFX = shingles("roofx", roof_c, along="X")
    TRIM = flat("trim", (0.85, 0.84, 0.8), 0.5)
    DOOR = flat("door", door_c, 0.45)
    GARAGE = flat("garage", (0.8, 0.78, 0.74), 0.55)
    GLINE = flat("gline", (0.6, 0.58, 0.55))
    GLASS = glass("glass")
    BRICK = brick("brick")
    CONC = flat("concrete", (0.55, 0.54, 0.51), 0.9)
    box("walls", X0, X1, Y0, Y1, 0.0, WALL, SIDE)
    box("found", X0 - 0.02, X1 + 0.02, Y0 - 0.02, Y1 + 0.02, 0.0, 0.09, CONC)
    RX = CX
    top = WALL + RISE
    xa, xb = X0 - OV, X1 + OV
    ya, yb = Y0 - OV, Y1 + OV
    drop = RISE * OV / (NV / 2)
    if style == "gable":
        for y, nm in ((Y1, "gableF"), (Y0, "gableB")):
            mesh(nm, [(X0, y, WALL), (X1, y, WALL), (RX, y, top)], [(0, 1, 2)], SIDE, 0.04)
        mesh("roofF", [(xb, ya, WALL - drop), (xb, yb, WALL - drop), (RX, yb, top), (RX, ya, top)], [(0, 1, 2, 3)], ROOF, 0.08)
        mesh("roofB", [(xa, ya, WALL - drop), (RX, ya, top), (RX, yb, top), (xa, yb, WALL - drop)], [(0, 1, 2, 3)], ROOF, 0.08)
    else:
        # hip roof: the ridge stops half the short width in from each end
        inset = NV / 2 + OV
        r0, r1 = ya + inset, yb - inset
        mesh("roofF", [(xb, ya, WALL - drop), (xb, yb, WALL - drop), (RX, r1, top), (RX, r0, top)], [(0, 1, 2, 3)], ROOF, 0.08)
        mesh("roofB", [(xa, ya, WALL - drop), (RX, r0, top), (RX, r1, top), (xa, yb, WALL - drop)], [(0, 1, 2, 3)], ROOF, 0.08)
        mesh("hipE", [(xb, yb, WALL - drop), (xa, yb, WALL - drop), (RX, r1, top)], [(0, 1, 2)], ROOFX, 0.08)
        mesh("hipW", [(xa, ya, WALL - drop), (xb, ya, WALL - drop), (RX, r0, top)], [(0, 1, 2)], ROOFX, 0.08)
    box("fasciaF", xb - 0.03, xb + 0.03, ya, yb, WALL - drop - 0.12, WALL - drop, TRIM)
    box("fasciaB", xa - 0.03, xa + 0.03, ya, yb, WALL - drop - 0.12, WALL - drop, TRIM)
    for (x, y) in ((X1, Y1), (X0, Y1), (X1, Y0), (X0, Y0)):
        box("corner", x - 0.05, x + 0.05, y - 0.05, y + 0.05, 0.05, WALL, TRIM)
    if look % 3 != 1:
        box("chimney", RX - 0.75, RX - 0.3, Y0 + 1.4, Y0 + 1.85, WALL * 0.6, top + 0.3, BRICK)
        box("chimcap", RX - 0.79, RX - 0.26, Y0 + 1.36, Y0 + 1.89, top + 0.3, top + 0.36, CONC)

    def on_x(name, ya_, yb_, z0, z1, mat, depth=0.04):
        return box(name, X1 - 0.01, X1 + depth, ya_, yb_, z0, z1, mat)

    def on_y(name, xa_, xb_, z0, z1, mat, depth=0.04):
        return box(name, xa_, xb_, Y1 - 0.01, Y1 + depth, z0, z1, mat)

    def on_yb(name, xa_, xb_, z0, z1, mat, depth=0.04):
        return box(name, xa_, xb_, Y0 - depth, Y0 + 0.01, z0, z1, mat)

    def win(put, a_, b_):
        put("wtrim", a_ - 0.06, b_ + 0.06, 0.48, 1.18, TRIM, 0.03)
        put("wglass", a_, b_, 0.54, 1.12, GLASS, 0.05)
        put("wmull", (a_ + b_) / 2 - 0.02, (a_ + b_) / 2 + 0.02, 0.54, 1.12, TRIM, 0.06)
        put("wsill", a_ - 0.1, b_ + 0.1, 0.44, 0.49, TRIM, 0.08)
        put("shutL", a_ - 0.3, a_ - 0.08, 0.48, 1.18, DOOR, 0.04)
        put("shutR", b_ + 0.08, b_ + 0.3, 0.48, 1.18, DOOR, 0.04)

    # Street side (+X): garage at the west end, then the front door, then a window.
    gy0, gy1 = Y0 + 0.3, Y0 + 2.3
    on_x("gtrim", gy0 - 0.08, gy1 + 0.08, 0.0, 1.1, TRIM, 0.03)
    on_x("gdoor", gy0, gy1, 0.0, 1.03, GARAGE, 0.05)
    for k in range(1, 4):
        z = 1.03 * k / 4
        on_x("gpanel", gy0, gy1, z - 0.015, z + 0.015, GLINE, 0.06)
    dy0 = Y0 + 3.05
    on_x("dtrim", dy0 - 0.07, dy0 + 0.63, 0.09, 1.3, TRIM, 0.03)
    on_x("door", dy0, dy0 + 0.56, 0.09, 1.24, DOOR, 0.05)
    on_x("knob", dy0 + 0.44, dy0 + 0.49, 0.62, 0.67, flat("brass", (0.7, 0.55, 0.2), 0.3, 1.0), 0.09)
    on_x("light", dy0 + 0.72, dy0 + 0.82, 1.0, 1.14, flat("lamp", (1.0, 0.9, 0.6), 0.2), 0.08)
    box("porch", X1, X1 + 0.6, dy0 - 0.25, dy0 + 0.85, 0.0, 0.08, CONC)
    win(on_x, Y0 + 4.05, Y0 + 4.65)
    # Sides and back: windows so every turn has something to look at.
    win(on_y, X0 + 0.8, X0 + 1.8)
    win(on_y, X0 + 2.6, X0 + 3.2)
    win(on_yb, X0 + 1.2, X0 + 2.4)

    def on_xb(name, ya_, yb_, z0, z1, mat, depth=0.04):
        return box(name, X0 - depth, X0 + 0.01, ya_, yb_, z0, z1, mat)
    win(on_xb, Y0 + 0.8, Y0 + 1.8)
    win(on_xb, Y0 + 3.0, Y0 + 4.0)
    box("backdoor", X0 - 0.05, X0 + 0.01, Y0 + 2.2, Y0 + 2.75, 0.09, 1.24, DOOR)


def lights_and_camera(scene, w_px=W_PX):
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.62, 0.72, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(4)
    bpy.context.collection.objects.link(sun)
    ground = box("ground", -12, 12, -12, 12, -0.02, 0.0, flat("g", (0.3, 0.3, 0.3)))
    ground.is_shadow_catcher = True
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = w_px / PX_PER_UNIT
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    return sun, cam


def aim(obj, pos, target):
    obj.location = pos
    d = Vector(target) - Vector(pos)
    obj.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def render_look(look):
    scene = new_scene()
    build(look)
    sun, cam = lights_and_camera(scene)
    objs = [o for o in bpy.data.objects if o.type == "MESH" and o.name != "ground"]
    pivot = Vector((CX, CY, 0))
    for o in objs:
        o["base_loc"] = list(o.location)
        o["base_rot"] = o.rotation_euler.z
    for turn in range(4):
        ang = -math.pi / 2 * turn
        rotz = Euler((0, 0, ang))
        for o in objs:
            bl = Vector(o["base_loc"]) - pivot
            bl.rotate(rotz)
            o.location = bl + pivot
            o.rotation_euler.z = o["base_rot"] + ang
        cells = []
        for gx in range(int(NU)):
            for gy in range(int(NV)):
                p = Vector((X1 - 0.5 - gy, Y1 - 0.5 - gx, 0)) - pivot
                p.rotate(rotz)
                cells.append(p + pivot)
        anchor = max(cells, key=lambda v: round(v.x + v.y, 3))
        el = math.radians(30)
        dist = 40
        pos = anchor + Vector((math.cos(el) * dist / math.sqrt(2), math.cos(el) * dist / math.sqrt(2), math.sin(el) * dist))
        aim(cam, pos, anchor)
        aim(sun, anchor + Vector((10, 4, 14)), anchor)
        cam.data.shift_x = 0.0
        cam.data.shift_y = 0.0
        bpy.context.view_layer.update()
        v = world_to_camera_view(scene, cam, anchor)
        # a 4 x 5 view (odd turn) reaches further right, so its anchor sits left of centre
        ax_px = 352 if turn % 2 == 0 else 288
        cam.data.shift_x = v.x - ax_px / W_PX
        cam.data.shift_y = (v.y - (1 - 460 / H_PX)) * H_PX / W_PX
        scene.render.filepath = os.path.join(OUT, "h%d_%d.png" % (look, turn))
        bpy.ops.render.render(write_still=True)
        print("rendered", scene.render.filepath, flush=True)


if __name__ == "__main__":
    for lk in (ONLY or range(len(LOOKS))):
        render_look(lk)
