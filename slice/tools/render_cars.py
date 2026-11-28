#!/usr/bin/env python3
"""Render the street's vehicles from 3D models into game sprites.

Shares materials, camera and lighting with render_houses.py. Each vehicle sits on
two tiles: the nose tile at the origin and the tail tile one step back along
grid x. Turn 0 points the nose along grid +x (screen down-right); each turn is a
quarter turn clockwise on screen. Images are 384 x 320 with the front-most
tile's centre at pixel (200, 250) on even turns and (184, 250) on odd turns.

Writes assets/cars/<kind>_<turn>.png.
Run: python3 tools/render_cars.py [samples] [kind ...]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
from mathutils import Euler, Vector  # noqa: E402
from bpy_extras.object_utils import world_to_camera_view  # noqa: E402

import render_houses as rh  # noqa: E402

OUT = os.path.join(rh.ROOT, "assets", "cars")
os.makedirs(OUT, exist_ok=True)
SAMPLES = int(sys.argv[1]) if len(sys.argv) > 1 else 32
ONLY = sys.argv[2:]
W, H = 384, 320
M = 0.73   # tile units per metre (a 1.75 m person is about 100 px tall)

# Car frame: Blender Y is the length (nose +Y), X the width, origin = nose tile centre.
NOSE, TAIL = 0.85, -1.45


def paint(name, col, metal=0.35, rough=0.28):
    m, nt, b = rh.nodes_mat(name)
    b.inputs["Base Color"].default_value = list(col) + [1]
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if "Coat Weight" in b.inputs:
        b.inputs["Coat Weight"].default_value = 0.6
    return m


def bevel(o, w=0.05, seg=3):
    mod = o.modifiers.new("b", "BEVEL")
    mod.width = w
    mod.segments = seg
    return o


def prism(name, y0b, y1b, y0t, y1t, z0, z1, hw_b, hw_t, mat):
    """Cabin: a box whose top is narrower and shorter than its base."""
    v = [(-hw_b, y0b, z0), (hw_b, y0b, z0), (hw_b, y1b, z0), (-hw_b, y1b, z0),
         (-hw_t, y0t, z1), (hw_t, y0t, z1), (hw_t, y1t, z1), (-hw_t, y1t, z1)]
    f = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    return rh.mesh(name, v, f, mat)


def wheels(ys, hw, r, mat_tire, mat_hub):
    for y in ys:
        for s in (-1, 1):
            bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=0.16, vertices=20,
                                                location=(s * hw, y, r), rotation=(0, math.pi / 2, 0))
            o = bpy.context.object
            o.data.materials.append(mat_tire)
            bpy.ops.mesh.primitive_cylinder_add(radius=r * 0.55, depth=0.17, vertices=16,
                                                location=(s * hw, y, r), rotation=(0, math.pi / 2, 0))
            bpy.context.object.data.materials.append(mat_hub)


def lights_front(y, hw, z, round_=False):
    head = rh.flat("head", (1.0, 0.97, 0.85), 0.1)
    for s in (-1, 1):
        if round_:
            bpy.ops.mesh.primitive_cylinder_add(radius=0.07, depth=0.04, location=(s * (hw - 0.13), y + 0.01, z), rotation=(math.pi / 2, 0, 0))
            bpy.context.object.data.materials.append(head)
        else:
            rh.box("head", s * (hw - 0.2) - 0.1, s * (hw - 0.2) + 0.1, y - 0.01, y + 0.03, z - 0.035, z + 0.035, head)


def lights_rear(y, hw, z):
    tail = rh.flat("tail", (0.7, 0.05, 0.04), 0.2)
    for s in (-1, 1):
        rh.box("tail", s * (hw - 0.1) - 0.06, s * (hw - 0.1) + 0.06, y - 0.03, y + 0.01, z - 0.06, z + 0.06, tail)


def build(kind):
    tire = rh.flat("tire", (0.03, 0.03, 0.03), 0.8)
    hub = rh.flat("hub", (0.6, 0.6, 0.62), 0.3, 0.8)
    chrome = rh.flat("chrome", (0.8, 0.8, 0.82), 0.15, 1.0)
    dark = rh.flat("trimdark", (0.06, 0.06, 0.07), 0.6)
    glass = rh.glass("glass")
    if kind == "sedan":
        # a 2010s family sedan
        body = paint("paint", (0.12, 0.2, 0.36))
        hw = 0.5
        bevel(rh.box("body", -hw, hw, TAIL, NOSE, 0.13, 0.62, body), 0.09)
        bevel(prism("cabin", -1.05, 0.25, -0.85, -0.12, 0.6, 1.02, hw - 0.04, hw - 0.1, glass), 0.04)
        bevel(prism("roof", -0.84, -0.13, -0.82, -0.15, 1.0, 1.05, hw - 0.1, hw - 0.12, body), 0.02)
        rh.box("bumperF", -hw + 0.02, hw - 0.02, NOSE - 0.02, NOSE + 0.04, 0.14, 0.3, dark)
        rh.box("bumperR", -hw + 0.02, hw - 0.02, TAIL - 0.04, TAIL + 0.02, 0.14, 0.3, dark)
        rh.box("grille", -0.22, 0.22, NOSE - 0.01, NOSE + 0.03, 0.34, 0.44, dark)
        lights_front(NOSE + 0.02, hw, 0.5)
        lights_rear(TAIL, hw, 0.5)
        wheels((NOSE - 0.45, TAIL + 0.42), hw - 0.02, 0.24, tire, hub)
    elif kind == "rig":
        # a boxy '90s 4x4 with a roof rack (Prime's Cherokee-style rig)
        body = paint("paint", (0.16, 0.24, 0.17), 0.25, 0.4)
        hw = 0.5
        bevel(rh.box("body", -hw, hw, TAIL, NOSE - 0.05, 0.22, 0.74, body), 0.04)
        bevel(prism("cabin", TAIL + 0.05, 0.2, TAIL + 0.08, 0.02, 0.72, 1.18, hw - 0.03, hw - 0.06, glass), 0.02)
        rh.box("roof", -hw + 0.06, hw - 0.06, TAIL + 0.08, 0.02, 1.16, 1.2, body)
        for x in (-hw + 0.1, hw - 0.1):
            rh.box("rail", x - 0.025, x + 0.025, TAIL + 0.2, -0.05, 1.2, 1.27, dark)
        for y in (TAIL + 0.35, -0.6, -0.15):
            rh.box("bar", -hw + 0.1, hw - 0.1, y - 0.025, y + 0.025, 1.25, 1.28, dark)
        rh.box("pillar", -hw + 0.02, hw - 0.02, -0.42, -0.36, 0.72, 1.17, body)
        rh.box("flare", -hw - 0.04, hw + 0.04, TAIL, NOSE - 0.05, 0.22, 0.36, dark)
        rh.box("bumperF", -hw, hw, NOSE - 0.07, NOSE + 0.02, 0.2, 0.34, dark)
        rh.box("bumperR", -hw, hw, TAIL - 0.05, TAIL + 0.02, 0.2, 0.34, dark)
        rh.box("grille", -0.32, 0.32, NOSE - 0.06, NOSE - 0.02, 0.42, 0.62, dark)
        rh.box("spare", -0.18, 0.18, TAIL - 0.16, TAIL - 0.04, 0.45, 0.8, tire)
        lights_front(NOSE - 0.04, hw, 0.52)
        lights_rear(TAIL, hw, 0.62)
        wheels((NOSE - 0.5, TAIL + 0.45), hw - 0.01, 0.27, tire, hub)
    elif kind == "old_iron":
        # a 1968 pickup: rounded cab and fenders, chrome bumpers, two-tone paint
        body = paint("paint", (0.2, 0.45, 0.45), 0.15, 0.5)
        white = paint("paint2", (0.85, 0.84, 0.78), 0.1, 0.5)
        hw = 0.5
        bevel(rh.box("hood", -hw + 0.06, hw - 0.06, -0.1, NOSE - 0.04, 0.3, 0.72, body), 0.1, 4)
        bevel(rh.box("fenderL", -hw, -hw + 0.22, 0.0, NOSE - 0.06, 0.2, 0.58, body), 0.08, 4)
        bevel(rh.box("fenderR", hw - 0.22, hw, 0.0, NOSE - 0.06, 0.2, 0.58, body), 0.08, 4)
        bevel(rh.box("cab", -hw + 0.04, hw - 0.04, -0.62, -0.08, 0.3, 0.8, body), 0.06, 3)
        bevel(prism("glass", -0.6, -0.12, -0.58, -0.2, 0.78, 1.18, hw - 0.06, hw - 0.1, glass), 0.03)
        bevel(rh.box("roof", -hw + 0.09, hw - 0.09, -0.6, -0.18, 1.14, 1.22, white), 0.04)
        bed = rh.box("bed", -hw + 0.02, hw - 0.02, TAIL + 0.03, -0.64, 0.3, 0.78, body)
        bevel(bed, 0.04)
        rh.box("bedfloor", -hw + 0.08, hw - 0.08, TAIL + 0.1, -0.7, 0.76, 0.8, rh.flat("wood", (0.35, 0.24, 0.14), 0.8))
        rh.box("bumperF", -hw - 0.02, hw + 0.02, NOSE - 0.04, NOSE + 0.04, 0.2, 0.3, chrome)
        rh.box("bumperR", -hw - 0.02, hw + 0.02, TAIL - 0.04, TAIL + 0.04, 0.2, 0.3, chrome)
        rh.box("grille", -0.3, 0.3, NOSE - 0.05, NOSE - 0.01, 0.36, 0.6, chrome)
        lights_front(NOSE - 0.02, hw, 0.5, round_=True)
        lights_rear(TAIL, hw, 0.6)
        wheels((NOSE - 0.42, TAIL + 0.45), hw - 0.02, 0.26, tire, hub)
    else:
        # a neighbor's modern full-size pickup
        body = paint("paint", (0.86, 0.86, 0.84), 0.3, 0.3)
        hw = 0.53
        bevel(rh.box("front", -hw, hw, -0.4, NOSE, 0.22, 0.82, body), 0.07)
        bevel(prism("cab", -0.62, 0.25, -0.58, 0.02, 0.8, 1.28, hw - 0.03, hw - 0.07, glass), 0.03)
        rh.box("roof", -hw + 0.07, hw - 0.07, -0.58, 0.02, 1.26, 1.31, body)
        rh.box("cabbody", -hw, hw, -0.64, -0.4, 0.22, 0.82, body)
        bevel(rh.box("bed", -hw, hw, TAIL, -0.66, 0.22, 0.86, body), 0.04)
        rh.box("bedin", -hw + 0.07, hw - 0.07, TAIL + 0.07, -0.72, 0.6, 0.87, dark)
        rh.box("bumperF", -hw, hw, NOSE - 0.02, NOSE + 0.05, 0.2, 0.36, chrome)
        rh.box("bumperR", -hw, hw, TAIL - 0.05, TAIL + 0.02, 0.2, 0.34, chrome)
        rh.box("grille", -0.36, 0.36, NOSE - 0.01, NOSE + 0.03, 0.4, 0.7, dark)
        lights_front(NOSE + 0.02, hw, 0.64)
        lights_rear(TAIL, hw, 0.68)
        wheels((NOSE - 0.5, TAIL + 0.45), hw - 0.01, 0.3, tire, hub)


def render_kind(kind):
    scene = rh.new_scene(W, H)
    scene.cycles.samples = SAMPLES
    build(kind)
    sun, cam = rh.lights_and_camera(scene, W)
    objs = [o for o in bpy.data.objects if o.type == "MESH" and o.name != "ground"]
    pivot = Vector((0, -0.5, 0))
    for o in objs:
        o["bl"] = list(o.location)
        o["br"] = list(o.rotation_euler)
    for turn in range(4):
        ang = -math.pi / 2 * turn
        rz = Euler((0, 0, ang))
        for o in objs:
            p = Vector(o["bl"]) - pivot
            p.rotate(rz)
            o.location = p + pivot
            e = Euler(o["br"])
            m = rz.to_matrix() @ e.to_matrix()
            o.rotation_euler = m.to_euler()
        cells = []
        for c in ((0, 0, 0), (0, -1, 0)):
            p = Vector(c) - pivot
            p.rotate(rz)
            cells.append(p + pivot)
        anchor = max(cells, key=lambda v: round(v.x + v.y, 3))
        el = math.radians(30)
        d = 40
        pos = anchor + Vector((math.cos(el) * d / math.sqrt(2), math.cos(el) * d / math.sqrt(2), math.sin(el) * d))
        rh.aim(cam, pos, anchor)
        rh.aim(sun, anchor + Vector((10, 4, 14)), anchor)
        cam.data.shift_x = cam.data.shift_y = 0.0
        bpy.context.view_layer.update()
        v = world_to_camera_view(scene, cam, anchor)
        ax = 200 if turn % 2 == 0 else 184
        cam.data.shift_x = v.x - ax / W
        cam.data.shift_y = (v.y - (1 - 250 / H)) * H / W
        scene.render.filepath = os.path.join(OUT, "%s_%d.png" % (kind, turn))
        bpy.ops.render.render(write_still=True)
        print("rendered", scene.render.filepath, flush=True)


if __name__ == "__main__":
    for k in (ONLY or ["sedan", "rig", "old_iron", "pickup"]):
        render_kind(k)
