#!/usr/bin/env python3
"""Рендер превью моделей из JSON (tools/preview/export.luau) в PNG.

Ортографическая камера, трассировка лучей по примитивам Roblox (Block, Wedge, Ball, Cylinder),
освещение, имитация материалов (доски, кирпич, ржавчина, трава...), контуры деталей и сетка масштаба
(клетка = 1 стад, жирная линия = 4 стада). Это приближение: настоящие текстуры и свет Roblox
здесь не воспроизводятся — смотрим на силуэт, пропорции, цвета и детализацию.

Запуск: python3 tools/preview/render.py scene.json out.png [--size 520] [--cols 2]
"""
import argparse
import json
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFont

BG_TOP = np.array([0.16, 0.17, 0.21])
BG_BOTTOM = np.array([0.07, 0.07, 0.09])
LIGHT = np.array([-0.45, 0.8, -0.4])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
FILL = np.array([0.6, 0.3, 0.7])
FILL = FILL / np.linalg.norm(FILL)

TERRAIN_COLORS = {
    "Grass": (0.24, 0.29, 0.17),
    "LeafyGrass": (0.2, 0.26, 0.15),
    "Ground": (0.31, 0.25, 0.19),
    "Mud": (0.23, 0.18, 0.14),
    "Rock": (0.36, 0.35, 0.34),
    "Slate": (0.28, 0.28, 0.3),
    "Sand": (0.6, 0.55, 0.4),
}

VIEWS = {
    # имя: (направление взгляда камеры)
    "threequarter": (-0.62, -0.5, 0.62),
    "back": (0.62, -0.45, -0.62),
    "front": (0.0, -0.15, 1.0),
    "side": (-1.0, -0.12, 0.0),
    "top": (0.0001, -1.0, 0.0001),
}


def cf_matrix(c):
    pos = np.array(c[0:3], dtype=np.float64)
    r = np.array(c[3:12], dtype=np.float64).reshape(3, 3)
    return pos, r


def camera_basis(view):
    d = np.array(VIEWS[view], dtype=np.float64)
    d = d / np.linalg.norm(d)
    up = np.array([0.0, 1.0, 0.0])
    if abs(d @ up) > 0.99:
        up = np.array([0.0, 0.0, -1.0])
    right = np.cross(d, up)
    right /= np.linalg.norm(right)
    up2 = np.cross(right, d)
    return d, right, up2


def prim_corners(p):
    pos, r = cf_matrix(p["cf"])
    s = np.array(p["size"]) / 2
    corners = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                corners.append(pos + r @ (s * np.array([sx, sy, sz])))
    return np.array(corners)


def material_pattern(mat, wp, base):
    """Псевдотекстура по мировым координатам точки (wp: N x 3)."""
    x, y, z = wp[:, 0], wp[:, 1], wp[:, 2]
    k = np.ones(len(wp))
    if mat in ("Wood", "WoodPlanks"):
        grain = np.sin((x + z) * 9.0 + np.sin(y * 3.0) * 2.0) * 0.06
        k += grain
        if mat == "WoodPlanks":
            k -= ((np.mod(y * 1.25, 1.0) < 0.06) * 0.18)
    elif mat == "Brick":
        row = np.floor(y * 2.0)
        off = (np.mod(row, 2) * 0.5)
        mortar = (np.mod(y * 2.0, 1.0) < 0.12) | (np.mod((x + z) * 1.0 + off, 1.0) < 0.06)
        k -= mortar * 0.25
    elif mat in ("CorrodedMetal",):
        n = np.sin(x * 3.1) * np.sin(z * 2.7 + y * 1.3) * np.sin(y * 4.1)
        k += n * 0.12
    elif mat in ("Concrete", "Slate", "Rock", "Cobblestone", "Pavement", "Asphalt", "Basalt", "Limestone"):
        n = np.sin(x * 5.3 + y * 2.1) * np.sin(z * 4.7 - y * 3.3)
        k += n * 0.07
    elif mat in ("Grass", "LeafyGrass", "Ground", "Mud"):
        n = np.sin(x * 2.3) * np.sin(z * 2.9) + np.sin(x * 7.1 + z * 5.3) * 0.5
        k += n * 0.08
    elif mat == "DiamondPlate":
        k += ((np.mod(x * 2 + z * 2, 1.0) < 0.15) & (np.mod(y * 2 + x * 2, 1.0) < 0.15)) * 0.12
    elif mat in ("Fabric", "Leather"):
        k += np.sin(x * 20) * np.sin(y * 20) * 0.04
    elif mat in ("RoofShingles", "ClayRoofTiles"):
        k -= (np.mod(y * 2.5, 1.0) < 0.15) * 0.2
    return base * k[:, None]


def intersect(prim, ro, rd):
    """ro, rd: N x 3 (мир). Возвращает t (inf = промах) и нормаль в мире (N x 3)."""
    pos, r = cf_matrix(prim["cf"])
    o = (ro - pos) @ r  # в локальные (столбцы r — оси детали)
    d = rd @ r
    s = np.array(prim["size"], dtype=np.float64) / 2
    n = len(ro)
    t_hit = np.full(n, np.inf)
    nl = np.zeros((n, 3))
    shape = prim["shape"]
    eps = 1e-9
    if shape == "Ball":
        rad = min(s)
        b = np.sum(o * d, axis=1)
        c = np.sum(o * o, axis=1) - rad * rad
        disc = b * b - c
        ok = disc >= 0
        t = -b - np.sqrt(np.where(ok, disc, 0))
        ok &= t > 1e-4
        t_hit = np.where(ok, t, np.inf)
        p = o + d * t_hit[:, None]
        nl = np.where(ok[:, None], p / max(rad, eps), 0)
    elif shape == "Cylinder":
        rad = min(s[1], s[2])
        h = s[0]
        # боковая поверхность (ось X)
        a = d[:, 1] ** 2 + d[:, 2] ** 2
        b = 2 * (o[:, 1] * d[:, 1] + o[:, 2] * d[:, 2])
        c = o[:, 1] ** 2 + o[:, 2] ** 2 - rad * rad
        disc = b * b - 4 * a * c
        ok = (disc >= 0) & (a > eps)
        t1 = (-b - np.sqrt(np.where(ok, disc, 0))) / np.where(a > eps, 2 * a, 1)
        x1 = o[:, 0] + d[:, 0] * t1
        side = ok & (t1 > 1e-4) & (np.abs(x1) <= h)
        t_side = np.where(side, t1, np.inf)
        # торцы
        tc = np.full(n, np.inf)
        ncap = np.zeros(n)
        for sign in (-1, 1):
            with np.errstate(divide="ignore", invalid="ignore"):
                tt = (sign * h - o[:, 0]) / np.where(np.abs(d[:, 0]) > eps, d[:, 0], np.nan)
            yy = o[:, 1] + d[:, 1] * tt
            zz = o[:, 2] + d[:, 2] * tt
            capok = (tt > 1e-4) & (yy * yy + zz * zz <= rad * rad)
            better = capok & (tt < tc)
            tc = np.where(better, tt, tc)
            ncap = np.where(better, sign, ncap)
        use_cap = tc < t_side
        t_hit = np.where(use_cap, tc, t_side)
        p = o + d * np.where(np.isfinite(t_hit), t_hit, 0)[:, None]
        nside = np.stack([np.zeros(n), p[:, 1], p[:, 2]], axis=1) / max(rad, eps)
        ncapv = np.stack([ncap, np.zeros(n), np.zeros(n)], axis=1)
        nl = np.where(use_cap[:, None], ncapv, nside)
    else:
        # коробка (+ плоскость клина) — метод плит для выпуклого многогранника
        planes = []
        for axis in range(3):
            for sign in (-1, 1):
                nrm = np.zeros(3)
                nrm[axis] = sign
                planes.append((nrm, s[axis]))
        if shape in ("Wedge", "CornerWedge"):
            # клин: y/sy <= z/sz  (высокая сторона сзади +Z, скат смотрит вперёд-вверх)
            nrm = np.array([0.0, 1.0 / max(s[1], eps), -1.0 / max(s[2], eps)])
            ln = np.linalg.norm(nrm)
            planes.append((nrm / ln, 0.0))
        tmin = np.full(n, 1e-4)
        tmax = np.full(n, np.inf)
        nmin = np.zeros((n, 3))
        alive = np.ones(n, dtype=bool)
        for nrm, dist in planes:
            denom = d @ nrm
            num = dist - (o @ nrm)
            par = np.abs(denom) < eps
            # параллельно плоскости: снаружи -> промах
            alive &= ~(par & (num < 0))
            with np.errstate(divide="ignore", invalid="ignore"):
                t = num / np.where(par, 1, denom)
            entering = (~par) & (denom < 0)
            leaving = (~par) & (denom > 0)
            upd = entering & (t > tmin)
            tmin = np.where(upd, t, tmin)
            nmin = np.where(upd[:, None], nrm, nmin)
            tmax = np.where(leaving & (t < tmax), t, tmax)
        ok = alive & (tmin <= tmax) & np.any(nmin != 0, axis=1)
        t_hit = np.where(ok, tmin, np.inf)
        nl = nmin
    nw = nl @ r.T
    norm = np.linalg.norm(nw, axis=1, keepdims=True)
    nw = nw / np.where(norm > 0, norm, 1)
    return t_hit, nw


def render_view(scene, view, size, ground=True):
    prims = list(scene["parts"])
    for t in scene.get("terrain", []):
        col = TERRAIN_COLORS.get(t["material"], (0.3, 0.3, 0.3))
        prims.append({**t, "color": list(col), "transparency": 0, "terrain": True})
    if not prims:
        return Image.new("RGB", (size, size), (20, 20, 24)), 0
    d, right, up = camera_basis(view)
    # границы сцены (детали без «земли», чтобы кадр был по модели)
    model_prims = [p for p in prims if not p.get("terrain")] or prims
    allc = np.concatenate([prim_corners(p) for p in model_prims])
    if scene.get("groundPlane"):
        # земля на y = 0 (как ландшафт в игре): закрывает утопленные в землю части
        glo, ghi = allc.min(axis=0), allc.max(axis=0)
        gx0, gz0 = (glo[0] + ghi[0]) / 2, (glo[2] + ghi[2]) / 2
        prims.append({
            "shape": "Block",
            "cf": [gx0, -0.05, gz0, 1, 0, 0, 0, 1, 0, 0, 0, 1],
            "size": [ghi[0] - glo[0] + 3, 0.1, ghi[2] - glo[2] + 3],
            "color": [0.2, 0.22, 0.17],
            "material": "SmoothPlastic",
            "transparency": 0,
            "terrain": True,
        })
    if ground and not scene.get("terrain"):
        lo = allc.min(axis=0)
        hi = allc.max(axis=0)
    else:
        lo = allc.min(axis=0)
        hi = allc.max(axis=0)
    center = (lo + hi) / 2
    proj_r = allc @ right
    proj_u = allc @ up
    half_w = max(proj_r.max() - proj_r.min(), proj_u.max() - proj_u.min()) / 2 * 1.12 + 0.5
    cr, cu = center @ right, center @ up
    W = H = size
    px = np.linspace(-half_w, half_w, W)
    py = np.linspace(half_w, -half_w, H)
    gx, gy = np.meshgrid(px, py)
    # луч стартует рядом со сценой: при 1000 стадах float32-матрицы портят проверку шаров
    origin = center[None, :] - d[None, :] * (np.linalg.norm(hi - lo) / 2 + 10.0)
    ro = origin + (gx.reshape(-1, 1) * right[None, :]) + (gy.reshape(-1, 1) * up[None, :])
    n = W * H
    depth = np.full(n, np.inf)
    normal = np.zeros((n, 3))
    color = np.zeros((n, 3))
    pid = np.full(n, -1)
    mats = np.empty(n, dtype=object)
    scale = (W - 1) / (2 * half_w)
    for i, p in enumerate(prims):
        c = prim_corners(p)
        rr = c @ right - cr
        uu = c @ up - cu
        x0 = int(max(0, math.floor((rr.min() + half_w) * scale) - 1))
        x1 = int(min(W - 1, math.ceil((rr.max() + half_w) * scale) + 1))
        y0 = int(max(0, math.floor((half_w - uu.max()) * scale) - 1))
        y1 = int(min(H - 1, math.ceil((half_w - uu.min()) * scale) + 1))
        if x1 < x0 or y1 < y0:
            continue
        ys, xs = np.mgrid[y0 : y1 + 1, x0 : x1 + 1]
        idx = (ys * W + xs).reshape(-1)
        rd = np.broadcast_to(d, (len(idx), 3))
        t, nw = intersect(p, ro[idx], rd)
        closer = t < depth[idx]
        if not closer.any():
            continue
        sel = idx[closer]
        depth[sel] = t[closer]
        normal[sel] = nw[closer]
        base = np.array(p.get("color", [0.6, 0.6, 0.6]))
        tr = p.get("transparency", 0)
        if tr > 0:
            base = base * (1 - tr * 0.5) + np.array([0.75, 0.8, 0.85]) * tr * 0.5
        color[sel] = base
        pid[sel] = i
        mats[sel] = p.get("material", "Plastic")
    hit = np.isfinite(depth)
    img = np.zeros((n, 3))
    # фон
    tgrad = (np.arange(n) // W) / H
    img[:] = BG_TOP[None, :] * (1 - tgrad[:, None]) + BG_BOTTOM[None, :] * tgrad[:, None]
    if hit.any():
        wp = ro[hit] + d[None, :] * depth[hit][:, None]
        nrm = normal[hit]
        base = color[hit]
        # материалы
        mh = mats[hit]
        for mat in set(mh):
            m = mh == mat
            base[m] = material_pattern(mat, wp[m], base[m])
        lam = np.clip(nrm @ LIGHT, 0, 1)
        fill = np.clip(nrm @ FILL, 0, 1) * 0.18
        amb = 0.32 + 0.12 * np.clip(nrm[:, 1], 0, 1)
        shade = amb + 0.75 * lam + fill
        out = base * shade[:, None]
        neon = mh == "Neon"
        out[neon] = np.clip(color[hit][neon] * 1.25 + 0.1, 0, 1)
        metal = np.isin(mh, ["Metal", "DiamondPlate", "Foil"])
        if metal.any():
            refl = 2 * (nrm[metal] @ LIGHT)[:, None] * nrm[metal] - LIGHT[None, :]
            spec = np.clip(refl @ (-d), 0, 1) ** 24
            out[metal] += spec[:, None] * 0.45
        img[hit] = np.clip(out, 0, 1)
    # контуры по смене детали и скачку глубины
    pid2 = pid.reshape(H, W)
    dep2 = np.where(hit, depth, 1e9).reshape(H, W)
    edge = np.zeros((H, W), dtype=bool)
    for dy, dx in ((0, 1), (1, 0)):
        a = pid2[: H - dy, : W - dx]
        b = pid2[dy:, dx:]
        da = dep2[: H - dy, : W - dx]
        db = dep2[dy:, dx:]
        diff = (a != b) & ((np.abs(da - db) > 0.15) | (a == -1) | (b == -1))
        edge[: H - dy, : W - dx] |= diff
        edge[dy:, dx:] |= diff
    img2 = img.reshape(H, W, 3)
    img2[edge] *= 0.45
    # сетка масштаба на земле (y = 0) для видов сверху/сбоку
    return Image.fromarray((img2 * 255).astype(np.uint8)), half_w * 2


def load_font(size=12):
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
                 "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            pass
    return ImageFont.load_default()


FONT = None


def scale_bar(draw, size, world_width):
    studs = 4 if world_width < 30 else (10 if world_width < 120 else 50)
    px = size * studs / world_width
    y = size - 14
    draw.line([(10, y), (10 + px, y)], fill=(230, 230, 230), width=3)
    draw.text((14 + px, y - 8), f"{studs} st", fill=(230, 230, 230), font=FONT)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scene")
    ap.add_argument("out")
    ap.add_argument("--size", type=int, default=420)
    ap.add_argument("--cols", type=int, default=0)
    ap.add_argument("--views", default="")
    args = ap.parse_args()
    global FONT
    FONT = load_font(12)
    data = json.load(open(args.scene))
    tiles = []
    for sc in data["scenes"]:
        views = sc.get("views") or (args.views.split(",") if args.views else ["threequarter", "back"])
        for v in views:
            im, width = render_view(sc, v, args.size, sc.get("ground", True))
            dr = ImageDraw.Draw(im)
            dr.rectangle([0, 0, args.size, 18], fill=(0, 0, 0))
            dr.text((6, 2), f"{sc['title']} — {v}", fill=(240, 240, 240), font=FONT)
            scale_bar(dr, args.size, width)
            tiles.append(im)
    if not tiles:
        print("nothing to render")
        return
    cols = args.cols or min(len(tiles), 4)
    rows = math.ceil(len(tiles) / cols)
    sheet = Image.new("RGB", (cols * args.size, rows * args.size), (10, 10, 12))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % cols) * args.size, (i // cols) * args.size))
    sheet.save(args.out)
    print(f"rendered {len(tiles)} tile(s) -> {args.out}")


if __name__ == "__main__":
    main()
