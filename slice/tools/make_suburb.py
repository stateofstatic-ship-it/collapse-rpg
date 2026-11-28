#!/usr/bin/env python3
"""Gray-box art for the cul-de-sac: one-story houses and yard props.

Writes assets/suburb.png (2048 x 2048). Layout, read by game/explore.gd:
  Houses: 6 slots of 640 x 512 at (i % 3 * 640, i // 3 * 512). The front cell's
  centre sits at slot (352, 460). Footprint 5 cells along grid x by 4 along grid y,
  behind that cell. Flip the sprite to get a 4 x 5 house.
  Props: 256 x 256 slots from y 1024, 8 per row, index j at
  (j % 8 * 256, 1024 + j // 8 * 256). The cell centre sits at slot (128, 240).

Run: python3 tools/make_suburb.py   (from the slice folder)
"""
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "suburb.png")
SS = 2  # supersample
rng = random.Random(3)

PROPS = ["mailbox", "mailbox2", "fence_x", "fence_y", "hedge", "bush", "bins", "hoop",
         "fir", "fir2", "maple", "maple2", "bike", "sale", "busstop", "pumpkin",
         "car_x", "car_y", "truck_x", "truck_y"]


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + ((c[3],) if len(c) > 3 else (255,))


def mix(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3)) + (255,)


class Iso:
    """Projects (u, v, z) in tile units / pixels onto a slot image.
    u runs toward the left corner, v toward the right corner."""

    def __init__(self, draw, ox, oy):
        self.d = draw
        self.ox, self.oy = ox, oy

    def p(self, u, v, z=0.0):
        # Origin is the bottom corner of the front cell (cell centre + 32 px).
        return ((self.ox + (-64 * u + 64 * v)) * SS, (self.oy + 32 - 32 * u - 32 * v - z) * SS)

    def poly(self, pts, fill, outline=None, width=1):
        self.d.polygon([self.p(*q) for q in pts], fill=fill, outline=outline)
        if outline is not None and width > 1:
            pp = [self.p(*q) for q in pts]
            self.d.line(pp + [pp[0]], fill=outline, width=width * SS)

    def line(self, a, b, fill, width=1):
        self.d.line([self.p(*a), self.p(*b)], fill=fill, width=max(1, int(width * SS)))


# ------------------------------------------------------------------ houses
SIDING = [(142, 160, 132), (126, 146, 166), (196, 178, 140), (226, 222, 210), (160, 92, 78), (110, 118, 124)]
TRIM = (240, 238, 228)
ROOFS = [(62, 64, 70), (88, 72, 60), (70, 74, 82), (58, 60, 58), (92, 86, 80), (64, 58, 54)]
DOORS = [(120, 40, 36), (36, 60, 90), (40, 70, 50), (150, 110, 40), (30, 30, 34), (110, 40, 70)]
NU = 5.0      # footprint along u (grid x)
NV = 4.0      # footprint along v (grid y)
HW = 112.0    # wall height px (a person is about 100 px)
RISE = 96.0   # roof rise px
OV = 0.22     # eave overhang in cells
AX, AY = 352, 460


def wall_face(iso, axis, col, light, door_col, garage, door, windows):
    """axis 'v0': the face v = 0 (length NU, runs toward the left corner).
    axis 'u0': the face u = 0 (length NV, runs toward the right corner)."""
    L = NU if axis == "v0" else NV

    def P(t, z):
        return (t, 0.0, z) if axis == "v0" else (0.0, t, z)
    c = shade(col, light)
    iso.poly([P(0, 0), P(L, 0), P(L, HW), P(0, HW)], c)
    for z in range(10, int(HW), 10):
        iso.line(P(0, z), P(L, z), shade(c, 0.9), 1)
    iso.poly([P(0, 0), P(L, 0), P(L, 8), P(0, 8)], shade((128, 124, 118), light))
    iso.line(P(0, 0), P(0, HW), TRIM, 3)
    iso.line(P(L, 0), P(L, HW), shade(TRIM, 0.85), 3)
    glass = (70, 92, 110, 255)
    for (a, b) in windows:
        iso.poly([P(a, 44), P(b, 44), P(b, 92), P(a, 92)], TRIM)
        iso.poly([P(a + 0.06, 48), P(b - 0.06, 48), P(b - 0.06, 88), P(a + 0.06, 88)], glass)
        m = (a + b) / 2
        iso.line(P(m, 48), P(m, 88), TRIM, 2)
        iso.line(P(a + 0.06, 68), P(b - 0.06, 68), TRIM, 2)
        # shutters
        iso.poly([P(a - 0.16, 44), P(a, 44), P(a, 92), P(a - 0.16, 92)], shade(door_col, light * 0.9))
        iso.poly([P(b, 44), P(b + 0.16, 44), P(b + 0.16, 92), P(b, 92)], shade(door_col, light * 0.9))
    if garage is not None:
        a, b = garage
        iso.poly([P(a, 8), P(b, 8), P(b, 92), P(a, 92)], TRIM)
        iso.poly([P(a + 0.08, 8), P(b - 0.08, 8), P(b - 0.08, 87), P(a + 0.08, 87)], shade((214, 210, 200), light))
        for z in (24, 40, 56, 72):
            iso.line(P(a + 0.08, z), P(b - 0.08, z), shade((170, 166, 158), light), 1.5)
    if door is not None:
        a = door
        iso.poly([P(a, 8), P(a + 0.62, 8), P(a + 0.62, 104), P(a, 104)], TRIM)
        iso.poly([P(a + 0.07, 8), P(a + 0.55, 8), P(a + 0.55, 99), P(a + 0.07, 99)], shade(door_col, light))
        kp = iso.p(*P(a + 0.45, 52))
        iso.d.ellipse([kp[0] - 2.5 * SS, kp[1] - 2.5 * SS, kp[0] + 2.5 * SS, kp[1] + 2.5 * SS], fill=(220, 190, 90))
        lp = iso.p(*P(a + 0.8, 84))
        iso.d.ellipse([lp[0] - 4 * SS, lp[1] - 5 * SS, lp[0] + 4 * SS, lp[1] + 5 * SS], fill=(250, 230, 160))
        if axis == "v0":
            iso.poly([(a - 0.1, 0, 0), (a + 0.72, 0, 0), (a + 0.72, -0.35, 0), (a - 0.1, -0.35, 0)], (150, 146, 140))
        else:
            iso.poly([(0, a - 0.1, 0), (0, a + 0.72, 0), (-0.35, a + 0.72, 0), (-0.35, a - 0.1, 0)], (150, 146, 140))


def gable_end(iso, axis, col, light):
    L = NU if axis == "v0" else NV

    def P(t, z):
        return (t, 0.0, z) if axis == "v0" else (0.0, t, z)
    c = shade(col, light)
    iso.poly([P(0, HW), P(L, HW), P(L / 2, HW + RISE)], c)
    for z in range(int(HW) + 10, int(HW + RISE), 10):
        f = (z - HW) / RISE
        iso.line(P(L / 2 * f + 0.05, z), P(L - L / 2 * f - 0.05, z), shade(c, 0.9), 1)
    iso.poly([P(L / 2 - 0.3, HW + 26), P(L / 2 + 0.3, HW + 26), P(L / 2, HW + 58)], shade((60, 60, 60), light))


def roof_lines(iso, r, a0, a1, b0, b1, along_u, drop):
    for k in range(1, 10):
        t = k / 10.0
        w = b0 + (b1 - b0) * t
        z = HW - drop + (RISE + drop) * t
        if along_u:
            iso.line((a0, w, z), (a1, w, z), shade(r, 0.82), 1)
        else:
            iso.line((w, a0, z), (w, a1, z), shade(r, 0.82), 1)


def chimney(iso, u, v, z0, z1):
    s = 0.42
    iso.poly([(u, v, z0), (u + s, v, z0), (u + s, v, z1), (u, v, z1)], (128, 70, 58))
    iso.poly([(u, v, z0), (u, v + s, z0), (u, v + s, z1), (u, v, z1)], (150, 84, 68))
    iso.poly([(u, v, z1), (u + s, v, z1), (u + s, v + s, z1), (u, v + s, z1)], (90, 50, 42))


def house(img, sx, sy, idx):
    col, roof, dcol = SIDING[idx], ROOFS[idx], DOORS[idx]
    ridge_u = idx % 2 == 0
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    siso = Iso(ImageDraw.Draw(sh), sx + AX, sy + AY - 32)
    siso.poly([(-0.3, -0.3, 0), (NU + 0.5, -0.3, 0), (NU + 0.5, NV + 0.5, 0), (-0.3, NV + 0.5, 0)], (0, 0, 0, 70))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(10 * SS)))
    iso = Iso(ImageDraw.Draw(img), sx + AX, sy + AY - 32)
    LEFT, RIGHT = 0.78, 0.98
    trim = shade(TRIM, 0.95)
    if ridge_u:
        # Ridge along the long side. Garage and window on the long wall, door on the gable end.
        wall_face(iso, "v0", col, LEFT, dcol, garage=(2.9, 4.7), door=None, windows=[(0.7, 1.7)])
        wall_face(iso, "u0", col, RIGHT, dcol, garage=None, door=0.5, windows=[(1.9, 3.1)])
        gable_end(iso, "u0", col, RIGHT)
        r = roof
        drop = RISE * OV / (NV / 2)
        top = HW + RISE
        iso.poly([(-OV, NV / 2, top), (NU + OV, NV / 2, top), (NU + OV, NV + OV, HW - drop), (-OV, NV + OV, HW - drop)], shade(r, 0.75))
        iso.poly([(-OV, -OV, HW - drop), (NU + OV, -OV, HW - drop), (NU + OV, NV / 2, top), (-OV, NV / 2, top)], r)
        roof_lines(iso, r, -OV, NU + OV, -OV, NV / 2, True, drop)
        iso.line((-OV, -OV, HW - drop), (-OV, NV / 2, top), trim, 3)
        iso.line((-OV, NV / 2, top), (-OV, NV + OV, HW - drop), trim, 3)
        iso.line((-OV, NV / 2, top), (NU + OV, NV / 2, top), shade(r, 0.6), 3)
        iso.line((-OV, -OV, HW - drop), (NU + OV, -OV, HW - drop), shade(TRIM, 0.8), 3)
        chimney(iso, 3.6, 1.0, HW + 50, top + 22)
    else:
        # Ridge across: a wide gable over the garage, door and windows on the eave wall.
        wall_face(iso, "v0", col, LEFT, dcol, garage=(1.6, 3.4), door=None, windows=[])
        wall_face(iso, "u0", col, RIGHT, dcol, garage=None, door=1.7, windows=[(0.45, 1.35), (2.75, 3.65)])
        gable_end(iso, "v0", col, LEFT)
        r = shade(roof, 1.08)
        drop = RISE * OV / (NU / 2)
        top = HW + RISE
        iso.poly([(NU / 2, -OV, top), (NU / 2, NV + OV, top), (NU + OV, NV + OV, HW - drop), (NU + OV, -OV, HW - drop)], shade(r, 0.75))
        iso.poly([(-OV, -OV, HW - drop), (-OV, NV + OV, HW - drop), (NU / 2, NV + OV, top), (NU / 2, -OV, top)], r)
        roof_lines(iso, r, -OV, NV + OV, -OV, NU / 2, False, drop)
        iso.line((-OV, -OV, HW - drop), (NU / 2, -OV, top), trim, 3)
        iso.line((NU / 2, -OV, top), (NU + OV, -OV, HW - drop), trim, 3)
        iso.line((NU / 2, -OV, top), (NU / 2, NV + OV, top), shade(r, 0.6), 3)
        iso.line((-OV, -OV, HW - drop), (-OV, NV + OV, HW - drop), shade(TRIM, 0.8), 3)


# ------------------------------------------------------------------ props
def prop(img, sx, sy, kind):
    d = ImageDraw.Draw(img)
    iso = Iso(d, sx + 128, sy + 240 - 32)   # cell centre at (128, 240)
    c0 = 0.5  # cell centre in (u, v) from the front corner

    def box(u0, v0, u1, v1, z0, z1, col):
        iso.poly([(u0, v0, z1), (u1, v0, z1), (u1, v1, z1), (u0, v1, z1)], shade(col, 1.1))
        iso.poly([(u0, v0, z0), (u1, v0, z0), (u1, v0, z1), (u0, v0, z1)], shade(col, 0.8))
        iso.poly([(u0, v0, z0), (u0, v1, z0), (u0, v1, z1), (u0, v0, z1)], shade(col, 0.95))

    def blob(cx, cy, r, col, n=7, spread=0.6):
        for k in range(n):
            ox = rng.uniform(-r * spread, r * spread)
            oy = rng.uniform(-r * spread, r * spread * 0.8)
            rr = r * rng.uniform(0.55, 0.8)
            f = 0.8 + 0.35 * (1 - (oy + r) / (2 * r))
            d.ellipse([(cx + ox - rr) * SS, (cy + oy - rr) * SS, (cx + ox + rr) * SS, (cy + oy + rr) * SS], fill=shade(col, f))

    def shadow(rx, ry):
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(sh).ellipse([(sx + 128 - rx) * SS, (sy + 240 - ry) * SS, (sx + 128 + rx) * SS, (sy + 240 + ry) * SS], fill=(0, 0, 0, 60))
        img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(4 * SS)))

    if kind in ("mailbox", "mailbox2"):
        shadow(14, 7)
        d = ImageDraw.Draw(img); iso.d = d
        box(0.46, 0.46, 0.54, 0.54, 0, 46, (90, 70, 50))
        col = (40, 44, 48) if kind == "mailbox" else (200, 196, 186)
        box(0.3, 0.4, 0.7, 0.6, 46, 66, col)
        iso.line((0.36, 0.6, 62), (0.36, 0.6, 80), (190, 40, 30), 3)
    elif kind in ("fence_x", "fence_y"):
        # pickets along grid x (screen down-right) or grid y (down-left)
        wood = (222, 218, 206)
        ex, ey = (64, 32) if kind == "fence_x" else (-64, 32)
        cx, cy = sx + 128, sy + 240
        rails = []
        for k in range(9):
            t = -0.5 + k / 8.0
            px, py = cx + ex * t, cy + ey * t
            d.polygon([((px - 3) * SS, (py) * SS), ((px + 3) * SS, (py) * SS), ((px + 3) * SS, (py - 34) * SS), (px * SS, (py - 39) * SS), ((px - 3) * SS, (py - 34) * SS)],
                      fill=shade(wood, 0.92 if k % 2 else 1.0), outline=shade(wood, 0.7))
        for h in (10, 26):
            d.line([((cx - ex / 2) * SS, (cy - ey / 2 - h) * SS), ((cx + ex / 2) * SS, (cy + ey / 2 - h) * SS)], fill=shade(wood, 0.8), width=3 * SS)
    elif kind in ("hedge", "bush"):
        shadow(40, 18)
        d = ImageDraw.Draw(img)
        col = (52, 92, 48) if kind == "hedge" else (70, 104, 56)
        blob(128 + sx, sy + 220, 30, col, 9)
        if kind == "bush":
            for k in range(14):
                x = sx + 128 + rng.uniform(-26, 26); y = sy + 216 + rng.uniform(-20, 14)
                d.ellipse([(x - 3) * SS, (y - 3) * SS, (x + 3) * SS, (y + 3) * SS], fill=(196, 70, 90))
    elif kind == "bins":
        shadow(26, 12)
        d = ImageDraw.Draw(img); iso.d = d
        box(0.2, 0.35, 0.48, 0.65, 0, 40, (40, 70, 52))
        box(0.52, 0.35, 0.8, 0.65, 0, 40, (40, 70, 120))
    elif kind == "hoop":
        shadow(20, 8)
        d = ImageDraw.Draw(img); iso.d = d
        box(0.46, 0.46, 0.54, 0.54, 0, 120, (90, 92, 96))
        iso.poly([(0.3, 0.42, 110), (0.7, 0.42, 110), (0.7, 0.42, 150), (0.3, 0.42, 150)], (236, 236, 236), outline=(180, 40, 30))
        iso.line((0.4, 0.3, 112), (0.6, 0.3, 112), (220, 90, 30), 2.5)
    elif kind in ("fir", "fir2"):
        shadow(40, 18)
        d = ImageDraw.Draw(img)
        cx, base = sx + 128, sy + 240
        d.rectangle([(cx - 5) * SS, (base - 40) * SS, (cx + 5) * SS, base * SS], fill=(78, 56, 40))
        h = 200 if kind == "fir" else 170
        layers = 6
        for k in range(layers):
            t0 = k / layers
            y = base - 30 - (h - 30) * t0
            w = 52 * (1 - t0) + 10
            col = shade((40, 74, 52), 0.85 + 0.25 * t0)
            d.polygon([((cx - w) * SS, y * SS), ((cx + w) * SS, y * SS), (cx * SS, (y - (h - 30) / layers * 1.9) * SS)], fill=col)
    elif kind in ("maple", "maple2"):
        shadow(44, 20)
        d = ImageDraw.Draw(img)
        cx, base = sx + 128, sy + 240
        d.polygon([((cx - 6) * SS, base * SS), ((cx + 6) * SS, base * SS), ((cx + 4) * SS, (base - 90) * SS), ((cx - 4) * SS, (base - 90) * SS)], fill=(84, 62, 46))
        col = (196, 96, 36) if kind == "maple" else (204, 160, 52)
        blob(cx, base - 128, 52, col, 12, 0.7)
        # a few fallen leaves
        for k in range(10):
            x = cx + rng.uniform(-50, 50); y = base + rng.uniform(-14, 10)
            d.ellipse([(x - 2) * SS, (y - 1.5) * SS, (x + 2) * SS, (y + 1.5) * SS], fill=shade(col, 0.9))
    elif kind == "bike":
        cx, base = sx + 128, sy + 236
        for ox in (-16, 16):
            d.ellipse([(cx + ox - 11) * SS, (base - 22) * SS, (cx + ox + 11) * SS, base * SS], outline=(30, 30, 30), width=3 * SS)
        d.line([((cx - 16) * SS, (base - 11) * SS), (cx * SS, (base - 22) * SS), ((cx + 16) * SS, (base - 11) * SS)], fill=(40, 120, 190), width=3 * SS)
        d.line([(cx * SS, (base - 22) * SS), ((cx - 4) * SS, (base - 30) * SS)], fill=(40, 40, 40), width=3 * SS)
    elif kind == "sale":
        d = ImageDraw.Draw(img); iso.d = d
        box(0.48, 0.48, 0.52, 0.52, 0, 60, (240, 240, 236))
        iso.poly([(0.5, 0.3, 34), (0.5, 0.7, 34), (0.5, 0.7, 56), (0.5, 0.3, 56)], (200, 40, 40))
    elif kind == "busstop":
        d = ImageDraw.Draw(img); iso.d = d
        box(0.47, 0.47, 0.53, 0.53, 0, 110, (120, 124, 128))
        iso.poly([(0.5, 0.36, 92), (0.5, 0.64, 92), (0.5, 0.64, 124), (0.5, 0.36, 124)], (30, 90, 160))
        box(0.2, 0.1, 0.3, 0.9, 18, 22, (110, 80, 60))
    elif kind in ("car_x", "car_y", "truck_x", "truck_y"):
        truck = kind.startswith("truck")
        along_u = kind.endswith("_x")
        body = (58, 82, 120) if not truck else (150, 60, 40)
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
        siso = Iso(ImageDraw.Draw(sh), sx + 128, sy + 240 - 32)

        def B(a0, a1, b0, b1, z0, z1, col, isoo=None):
            # a runs along the car, b across it
            if along_u:
                box(a0, b0, a1, b1, z0, z1, col) if isoo is None else isoo.poly([(a0, b0, 0), (a1, b0, 0), (a1, b1, 0), (a0, b1, 0)], col)
            else:
                box(b0, a0, b1, a1, z0, z1, col) if isoo is None else isoo.poly([(b0, a0, 0), (b1, a0, 0), (b1, a1, 0), (b0, a1, 0)], col)
        B(-0.35, 1.35, 0.08, 0.92, 0, 0, (0, 0, 0, 80), siso)
        img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5 * SS)))
        d = ImageDraw.Draw(img); iso.d = d
        # wheels on the two visible sides
        for a in (-0.05, 1.0):
            for (u, v) in (((a, 0.12) if along_u else (0.12, a)), ((0.12, a + 0.2) if along_u else (a + 0.2, 0.12))):
                pp = iso.p(u, v, 12)
                d.ellipse([pp[0] - 9 * SS, pp[1] - 9 * SS, pp[0] + 9 * SS, pp[1] + 9 * SS], fill=(26, 26, 28))
        B(-0.3, 1.3, 0.14, 0.86, 10, 44, body)
        glass = (60, 80, 96)
        if truck:
            B(0.55, 1.15, 0.16, 0.84, 44, 78, body)
            B(0.62, 1.1, 0.13, 0.87, 50, 72, glass)
            box(*(((0.6, 0.18, 1.1, 0.82) if along_u else (0.18, 0.6, 0.82, 1.1))), 52, 70, glass)
            B(0.55, 1.15, 0.16, 0.84, 72, 78, body)
            B(-0.25, 0.5, 0.22, 0.78, 43, 44, shade(body, 0.55))
        else:
            B(0.05, 0.95, 0.18, 0.82, 44, 72, shade(body, 1.05))
            box(*(((0.1, 0.16, 0.9, 0.84) if along_u else (0.16, 0.1, 0.84, 0.9))), 48, 68, glass)
            B(0.05, 0.95, 0.18, 0.82, 68, 74, shade(body, 1.05))
        # headlights
        hp = iso.p(*((-0.3, 0.3, 32) if along_u else (0.3, -0.3, 32)))
        d.ellipse([hp[0] - 3 * SS, hp[1] - 3 * SS, hp[0] + 3 * SS, hp[1] + 3 * SS], fill=(240, 236, 200))
    elif kind == "pumpkin":
        cx, base = sx + 128, sy + 236
        for ox, r in ((-14, 15), (14, 11)):
            d.ellipse([(cx + ox - r - 3) * SS, (base - 2 * r) * SS, (cx + ox + r + 3) * SS, base * SS], fill=(222, 120, 30), outline=(170, 80, 20))
            d.line([((cx + ox) * SS, (base - 2 * r) * SS), ((cx + ox + 1) * SS, (base - 2 * r - 5) * SS)], fill=(70, 90, 40), width=3 * SS)


def main():
    img = Image.new("RGBA", (2048 * SS, 2048 * SS), (0, 0, 0, 0))
    for i in range(6):
        house(img, i % 3 * 640, i // 3 * 512, i)
    for j, k in enumerate(PROPS):
        prop(img, j % 8 * 256, 1024 + j // 8 * 256, k)
    img = img.resize((2048, 2048), Image.LANCZOS)
    img.save(OUT, optimize=True)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
