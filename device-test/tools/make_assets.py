#!/usr/bin/env python3
"""Generate gray-box placeholder art for the device stress test.

Sizes and counts follow design/chapters/art.md and tech.md:
128x64 diamond tiles, 160 px character frames with 8 facings, colour and
normal sheets with identical layouts. The look is placeholder only.

Run: python3 tools/make_assets.py   (from the project root)
"""
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets")
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(7)

FRAME = 160
COLS, ROWS = 12, 8  # 12 walk frames x 8 facings


def normal_from_height(h, strength=2.0):
    gy, gx = np.gradient(h)
    nx, ny, nz = -gx * strength, -gy * strength, np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / ln, ny / ln, nz / ln], axis=-1)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def save_pair(name, rgba, normal_rgb, alpha):
    Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, name + ".png"), optimize=True)
    n = np.dstack([normal_rgb, alpha])
    Image.fromarray(n, "RGBA").save(os.path.join(OUT, name + "_n.png"), optimize=True)


def value_noise(shape, scale, rng):
    h, w = shape
    gh, gw = h // scale + 2, w // scale + 2
    g = rng.random((gh, gw))
    ys = np.linspace(0, gh - 2, h, endpoint=False)
    xs = np.linspace(0, gw - 2, w, endpoint=False)
    y0, x0 = ys.astype(int), xs.astype(int)
    fy, fx = (ys - y0)[:, None], (xs - x0)[None, :]
    a = g[y0][:, x0]
    b = g[y0][:, x0 + 1]
    c = g[y0 + 1][:, x0]
    d = g[y0 + 1][:, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


# ---------------------------------------------------------------- tiles
def make_tiles():
    tw, th = 128, 64
    cols, rows = 8, 4
    kinds = [  # base colour, noise amp, roughness
        ((88, 98, 62), 40, 6),    # wet grass
        ((70, 72, 76), 18, 3),    # asphalt
        ((128, 122, 112), 22, 8),  # concrete
        ((96, 76, 56), 34, 5),    # mud
    ]
    W, H = tw * cols, th * rows
    rgba = np.zeros((H, W, 4), np.uint8)
    height = np.zeros((H, W), np.float32)
    yy, xx = np.mgrid[0:th, 0:tw]
    mask = (np.abs(xx - tw / 2 + 0.5) / (tw / 2) + np.abs(yy - th / 2 + 0.5) / (th / 2)) <= 1.0
    for r, (col, amp, rough) in enumerate(kinds):
        for c in range(cols):
            n = value_noise((th, tw), rough, RNG) * 0.6 + value_noise((th, tw), 2, RNG) * 0.4
            if r == 1 and c % 2 == 0:  # road stripe
                n += ((np.abs((xx - tw / 2) * 0.5 - (yy - th / 2)) < 2.5) * 1.2)
            if r == 2:  # concrete slabs
                n -= ((xx + yy * 2) % 64 < 2) * 0.8
            base = np.array(col, np.float32)
            px = base[None, None, :] + (n[..., None] - 0.5) * amp
            ox, oy = c * tw, r * th
            sub = rgba[oy:oy + th, ox:ox + tw]
            sub[..., :3] = np.where(mask[..., None], np.clip(px, 0, 255), 0).astype(np.uint8)
            sub[..., 3] = mask * 255
            height[oy:oy + th, ox:ox + tw] = n * mask
    save_pair("tiles", rgba, normal_from_height(height, 3.0), rgba[..., 3])


# ---------------------------------------------------------------- characters
def capsule(X, Y, a, b, r):
    ax, ay = a
    bx, by = b
    px, py = X - ax, Y - ay
    vx, vy = bx - ax, by - ay
    t = np.clip((px * vx + py * vy) / max(vx * vx + vy * vy, 1e-6), 0, 1)
    dx, dy = px - vx * t, py - vy * t
    d2 = dx * dx + dy * dy
    return np.sqrt(np.maximum(r * r - d2, 0))


def draw_figure(facing, phase, parts):
    """Return height map and part-id map for one 160 px frame.

    Adult is 94 px tall standing on y=150 (art.md)."""
    Y, X = np.mgrid[0:FRAME, 0:FRAME].astype(np.float32)
    ang = facing * math.pi / 4
    sx = math.cos(ang)       # screen-side component of facing
    sy = math.sin(ang) * 0.5  # depth component (iso squash)
    cx, foot = 80.0, 150.0
    hip = foot - 44
    shoulder = foot - 74
    stride = math.sin(phase) * 9
    bob = abs(math.cos(phase)) * 2
    layers = []  # (height, id)
    for side in (-1, 1):
        lx = cx + side * 6 * abs(sy) * 2 + side * 3
        fx = lx + side * stride * sx * 0.9
        fy = foot - side * stride * sy * 0.6
        layers.append((capsule(X, Y, (lx, hip - bob), (fx, fy), 6.0), 1))  # legs
    torso = capsule(X, Y, (cx, hip - bob - 2), (cx, shoulder - bob + 4), 12.0)
    layers.append((torso * 1.1, 2))
    for side in (-1, 1):
        ax = cx + side * 13
        hx = ax - side * stride * sx * 0.7
        layers.append((capsule(X, Y, (ax, shoulder - bob + 2), (hx, hip - bob + 6), 4.5), 3))
    head_y = foot - 94 + 10 - bob
    layers.append((capsule(X, Y, (cx + sx * 1.5, head_y), (cx + sx * 1.5, head_y + 2), 9.5) * 1.2, 4))
    if "pack" in parts:
        layers.append((capsule(X, Y, (cx - sx * 10, shoulder - bob + 8), (cx - sx * 10, hip - bob - 6), 9.0), 5))
    if "rifle" in parts:
        rh = capsule(X, Y, (cx + sx * 16, shoulder - bob + 6), (cx + sx * 30, hip - bob - 10), 2.5)
        layers.append((np.where(rh > 0, rh + 6, 0), 6))
    h = np.zeros((FRAME, FRAME), np.float32)
    ids = np.zeros((FRAME, FRAME), np.int32)
    for lh, lid in layers:
        take = lh > h
        h = np.where(take, lh, h)
        ids = np.where(take, lid, ids)
    return h, ids


def make_character(name, palette, parts=(), only=None):
    """palette: dict part-id -> rgb. only: restrict drawn ids (for layer sheets)."""
    W, H = FRAME * COLS, FRAME * ROWS
    rgba = np.zeros((H, W, 4), np.uint8)
    height = np.zeros((H, W), np.float32)
    for f in range(ROWS):
        for i in range(COLS):
            h, ids = draw_figure(f, i / COLS * 2 * math.pi, parts)
            if only is not None:
                keep = np.isin(ids, only)
                h = h * keep
                ids = ids * keep
            alpha = np.clip(h * 2.0, 0, 1)
            col = np.zeros((FRAME, FRAME, 3), np.float32)
            for pid, c in palette.items():
                col += (ids == pid)[..., None] * np.array(c, np.float32)
            shade = 0.75 + 0.25 * np.clip(h / 12.0, 0, 1)
            col *= shade[..., None]
            oy, ox = f * FRAME, i * FRAME
            rgba[oy:oy + FRAME, ox:ox + FRAME, :3] = np.clip(col, 0, 255).astype(np.uint8)
            rgba[oy:oy + FRAME, ox:ox + FRAME, 3] = (alpha * 255).astype(np.uint8)
            height[oy:oy + FRAME, ox:ox + FRAME] = h
    save_pair(name, rgba, normal_from_height(height, 0.6), rgba[..., 3])


def make_characters():
    looks = [
        ("char_survivor", {1: (60, 62, 70), 2: (120, 96, 60), 3: (190, 150, 120), 4: (200, 160, 130), 5: (80, 90, 60)}, ("pack",)),
        ("char_guard", {1: (40, 44, 40), 2: (70, 84, 60), 3: (70, 84, 60), 4: (170, 120, 90), 6: (30, 30, 30)}, ("rifle",)),
        ("char_raider", {1: (70, 50, 40), 2: (110, 40, 30), 3: (150, 110, 80), 4: (150, 110, 80), 6: (50, 50, 50)}, ("rifle",)),
        ("char_medic", {1: (200, 200, 210), 2: (220, 220, 230), 3: (230, 190, 160), 4: (230, 190, 160), 5: (180, 40, 40)}, ("pack",)),
        ("char_trader", {1: (80, 70, 50), 2: (150, 120, 70), 3: (120, 80, 60), 4: (120, 80, 60), 5: (110, 90, 50)}, ("pack",)),
        ("char_civilian", {1: (40, 50, 90), 2: (160, 60, 90), 3: (210, 170, 140), 4: (210, 170, 140)}, ()),
        ("char_worker", {1: (60, 60, 60), 2: (220, 150, 30), 3: (180, 130, 100), 4: (180, 130, 100), 5: (90, 90, 90)}, ("pack",)),
        ("char_elder", {1: (90, 90, 80), 2: (100, 110, 120), 3: (220, 200, 180), 4: (230, 220, 210)}, ()),
    ]
    for name, pal, parts in looks:
        make_character(name, pal, parts)
    # Family layer sheets: body in grayscale for the skin-ramp shader, then outfit, then item.
    gray = {1: (128, 128, 128), 2: (128, 128, 128), 3: (200, 200, 200), 4: (210, 210, 210)}
    make_character("layer_body", gray, (), only=[3, 4])
    make_character("layer_outfit", {1: (50, 60, 80), 2: (90, 110, 70)}, (), only=[1, 2])
    make_character("layer_item", {5: (100, 80, 50), 6: (40, 40, 40)}, ("pack", "rifle"), only=[5, 6])


# ---------------------------------------------------------------- props
def iso_box(rgba, height, ox, oy, w, d, hgt, col, rng):
    """Draw an iso box whose ground footprint is w x d tiles-ish, height hgt px.
    Faces get flat height ramps so the normal map shows three planes."""
    H, W = height.shape
    Y, X = np.mgrid[0:H, 0:W].astype(np.float32)
    # ground diamond corners relative to (ox, oy) = bottom vertex
    hw = (w + d) * 0.5
    left = (ox - d, oy - d * 0.5)
    right = (ox + w, oy - w * 0.5)
    top = (ox + w - d, oy - (w + d) * 0.5)
    def inside_poly(pts):
        res = np.ones_like(X, bool)
        n = len(pts)
        for k in range(n):
            x1, y1 = pts[k]
            x2, y2 = pts[(k + 1) % n]
            res &= ((x2 - x1) * (Y - y1) - (y2 - y1) * (X - x1)) >= 0
        return res
    b = (ox, oy)
    up = lambda p: (p[0], p[1] - hgt)
    lf = inside_poly([b, up(b), up(left), left][::-1]) | inside_poly([b, up(b), up(left), left])
    rf = inside_poly([b, right, up(right), up(b)][::-1]) | inside_poly([b, right, up(right), up(b)])
    tf = inside_poly([up(b), up(right), up(top), up(left)][::-1]) | inside_poly([up(b), up(right), up(top), up(left)])
    noise = rng.random((H, W)) * 0.15
    c = np.array(col, np.float32)
    for m, k, hramp in ((lf, 0.62, X * 0.8), (rf, 0.85, -X * 0.8), (tf, 1.05, -Y * 1.5)):
        m = m & (rgba[..., 3] == 0)
        rgba[m, :3] = np.clip(c * (k + noise[m][:, None]), 0, 255).astype(np.uint8)
        rgba[m, 3] = 255
        height[m] = hramp[m] - hramp[m].min() if m.any() else 0
    # windows on the right face
    if hgt > 60:
        wm = rf & (((X - ox) % 24) < 10) & (((Y + (X - ox) * 0.5) % 30) < 12)
        rgba[wm, :3] = (35, 40, 48)
        height[wm] -= 3


def make_props():
    S = 2048
    rgba = np.zeros((S, S, 4), np.uint8)
    height = np.zeros((S, S), np.float32)
    # Buildings: 4 x 2 slots of 512 x 1024 at the top half
    cols = [(150, 140, 120), (120, 110, 100), (170, 160, 150), (110, 120, 130)]
    for i in range(4):
        slot = np.zeros((1024, 512, 4), np.uint8)
        sh = np.zeros((1024, 512), np.float32)
        iso_box(slot, sh, 256, 1000, 220, 200, 380 + i * 90, cols[i], RNG)
        rgba[0:1024, i * 512:(i + 1) * 512] = slot
        height[0:1024, i * 512:(i + 1) * 512] = sh
    # Small props: 8 x 4 slots of 256 x 256 in the bottom half
    small_cols = [(90, 40, 30), (40, 60, 90), (70, 70, 72), (100, 100, 60), (60, 40, 30), (130, 120, 40), (30, 50, 40), (90, 90, 95)]
    for j in range(32):
        r, c = divmod(j, 8)
        slot = np.zeros((256, 256, 4), np.uint8)
        sh = np.zeros((256, 256), np.float32)
        kind = j % 4
        col = small_cols[j % 8]
        if kind == 0:   # car
            iso_box(slot, sh, 128, 240, 110, 50, 34, col, RNG)
            iso_box(slot, sh, 118, 205, 60, 44, 24, (60, 70, 80), RNG)
        elif kind == 1:  # crate / barrel stack
            iso_box(slot, sh, 128, 240, 40, 40, 40, (110, 90, 60), RNG)
            iso_box(slot, sh, 128, 200, 30, 30, 30, (100, 80, 55), RNG)
        elif kind == 2:  # tree (layered blobs)
            Y, X = np.mgrid[0:256, 0:256].astype(np.float32)
            hh = capsule(X, Y, (128, 240), (128, 160), 7)
            for k in range(6):
                bx, by = 128 + RNG.integers(-30, 30), 90 + RNG.integers(-40, 30)
                hh = np.maximum(hh, capsule(X, Y, (bx, by), (bx, by), 34 + RNG.integers(0, 14)))
            m = hh > 0
            g = 0.6 + 0.4 * np.clip(hh / 40, 0, 1)
            trunk = (X > 120) & (X < 136) & (Y > 150)
            colr = np.where(trunk[..., None], np.array([70, 50, 35]), np.array([45, 75, 40]))
            slot[m, :3] = np.clip(colr[m] * g[m][:, None] + RNG.random((m.sum(), 1)) * 20, 0, 255)
            slot[m, 3] = 255
            sh[:] = hh
        else:            # lamp post
            iso_box(slot, sh, 128, 245, 8, 8, 200, (60, 62, 66), RNG)
            iso_box(slot, sh, 140, 50, 30, 10, 10, (200, 200, 170), RNG)
        rgba[1024 + r * 256:1024 + (r + 1) * 256, c * 256:(c + 1) * 256] = slot
        height[1024 + r * 256:1024 + (r + 1) * 256, c * 256:(c + 1) * 256] = sh
    save_pair("props", rgba, normal_from_height(height, 0.5), rgba[..., 3])


# ---------------------------------------------------------------- portraits
def make_portraits():
    W, H = 128 * 6, 128
    img = np.zeros((H, W, 4), np.uint8)
    Y, X = np.mgrid[0:H, 0:128].astype(np.float32)
    skins = [(200, 160, 130), (150, 110, 80), (230, 190, 160), (120, 80, 60), (220, 200, 180), (150, 120, 80)]
    for i, s in enumerate(skins):
        hh = capsule(X, Y, (64, 56), (64, 62), 34) + capsule(X, Y, (64, 140), (64, 150), 54) * 0.6
        m = hh > 0
        col = np.where((Y > 92)[..., None], np.array([70, 80, 60]), np.array(s))
        sh = 0.6 + 0.4 * np.clip(hh / 34, 0, 1)
        sub = img[:, i * 128:(i + 1) * 128]
        sub[..., :3] = np.clip(col * sh[..., None], 0, 255) * m[..., None]
        sub[..., 3] = 255
        sub[m == 0, :3] = (30, 28, 24)
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, "portraits.png"), optimize=True)


if __name__ == "__main__":
    make_tiles()
    make_characters()
    make_props()
    make_portraits()
    print("assets written to", OUT)
