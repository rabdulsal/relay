"""
Relay Mac App — App Store Screenshot Generator
Generates 6 PNG files at 1280x800 and 1440x900
"""

from PIL import Image, ImageDraw, ImageFont
import os

# ── Output directory ────────────────────────────────────────────────
OUT_DIR = "/Users/abdulsar/Desktop/Project_Apps/Relay/mac-app/fastlane/screenshots/en-US"
os.makedirs(OUT_DIR, exist_ok=True)

# ── Palette ─────────────────────────────────────────────────────────
BG          = "#1c1c1e"   # macOS dark window
SURFACE     = "#2c2c2e"   # popup background
SURFACE2    = "#3a3a3c"   # card / row background
TEXT        = "#f2f2f7"   # primary text
TEXT_SEC    = "#8e8e93"   # secondary text
RELAY_BLUE  = "#3D7EF5"
RELAY_PINK  = "#F02D5A"
DIVIDER     = "#48484a"
MENUBAR_BG  = "#000000"
BADGE_URGENT_BG  = "#3D0A15"
BADGE_URGENT_FG  = RELAY_PINK
BADGE_HIGH_BG    = "#2B1A30"
BADGE_HIGH_FG    = "#D46BF5"
BADGE_MED_BG     = "#0E2040"
BADGE_MED_FG     = RELAY_BLUE
BADGE_PENDING_BG = "#2c2c2e"
BADGE_PENDING_FG = TEXT_SEC
BADGE_INPROG_BG  = "#0E2040"
BADGE_INPROG_FG  = RELAY_BLUE
BADGE_BLOCK_BG   = "#3D0A15"
BADGE_BLOCK_FG   = RELAY_PINK

def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

# ── Fonts ────────────────────────────────────────────────────────────
SFNS = "/System/Library/Fonts/SFNS.ttf"
HELVETICA = "/System/Library/Fonts/HelveticaNeue.ttc"

def load_font(size, bold=False):
    try:
        return ImageFont.truetype(SFNS, size)
    except Exception:
        try:
            return ImageFont.truetype(HELVETICA, size)
        except Exception:
            return ImageFont.load_default()

# ── Helper utilities ─────────────────────────────────────────────────
def rounded_rect(draw, xy, radius, fill=None, outline=None, width=1):
    x0, y0, x1, y1 = xy
    if fill:
        draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=fill,
                                outline=outline, width=width)
    else:
        draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=fill,
                                outline=outline, width=width)

def draw_badge(draw, text, x, y, bg, fg, font, pad_x=7, pad_h=4):
    bbox = font.getbbox(text)
    w = bbox[2] - bbox[0] + pad_x * 2
    h = bbox[3] - bbox[1] + pad_h * 2
    text_y_off = -bbox[1]
    rounded_rect(draw, [x, y, x+w, y+h], radius=5, fill=bg)
    draw.text((x + pad_x, y + pad_h + text_y_off - 1), text, font=font, fill=fg)
    return w, h

def gradient_line(img, x0, y0, x1, thickness=2):
    """Draw a horizontal blue→pink gradient line."""
    draw = ImageDraw.Draw(img)
    width = x1 - x0
    r0, g0, b0 = hex_to_rgb(RELAY_BLUE)
    r1, g1, b1 = hex_to_rgb(RELAY_PINK)
    for i in range(width):
        t = i / max(width - 1, 1)
        r = int(r0 + (r1 - r0) * t)
        g = int(g0 + (g1 - g0) * t)
        b = int(b0 + (b1 - b0) * t)
        for dy in range(thickness):
            draw.point((x0 + i, y0 + dy), fill=(r, g, b, 255))

def draw_popup_shadow(img, px, py, pw, ph, radius=12, shadow_spread=18):
    """Draw a soft drop shadow under the popup."""
    from PIL import ImageFilter
    shadow_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow_layer)
    sd.rounded_rectangle(
        [px + 4, py + 8, px + pw - 4, py + ph + 8],
        radius=radius, fill=(0, 0, 0, 120)
    )
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(shadow_spread))
    img.alpha_composite(shadow_layer)

def draw_menubar(img, draw, W, icon_color=RELAY_BLUE, count_text="2"):
    """Thin macOS-style menu bar at very top."""
    bar_h = 24
    draw.rectangle([0, 0, W, bar_h], fill="#161618")
    # Relay icon dot + count on right
    badge_x = W - 60
    badge_y = 4
    dot_r = 6
    draw.ellipse([badge_x, badge_y, badge_x + dot_r*2, badge_y + dot_r*2],
                 fill=icon_color)
    # Antenna lines (simple)
    cx = badge_x + dot_r
    for i, (dx, dy_start, dy_end) in enumerate([(-5, -3, 3), (-2, -5, 5), (1, -3, 3)]):
        draw.line([(cx + dx, badge_y + dot_r + dy_start),
                   (cx + dx, badge_y + dot_r + dy_end)],
                  fill=icon_color, width=1)
    fnt = load_font(11, bold=True)
    draw.text((badge_x + dot_r*2 + 3, badge_y + 1), count_text,
              font=fnt, fill=icon_color)

    # Standard macOS right-side clock/wifi placeholder
    fnt_sm = load_font(10)
    draw.text((W - 160, 5), "9:41 AM", font=fnt_sm, fill=TEXT_SEC)

def draw_popup_chrome(img, draw, px, py, pw, ph):
    """macOS-style window chrome (title bar with traffic lights)."""
    chrome_h = 28
    rounded_rect(draw, [px, py, px+pw, py+chrome_h+4], radius=12, fill=SURFACE)
    for i, color in enumerate(["#FF5F57", "#FFBD2E", "#28C840"]):
        cx = px + 12 + i * 20
        cy = py + 14
        draw.ellipse([cx-5, cy-5, cx+5, cy+5], fill=color)
    draw.rectangle([px, py+chrome_h, px+pw, py+ph], fill=SURFACE)

def draw_popup(img, draw, W, H, scenario="main", icon_color=RELAY_BLUE,
               count_text="2", show_overlay=False):
    """Draw the full 340px Relay popup centered on the canvas."""
    POPUP_W = 340
    POPUP_H = 420 if scenario != "settings" else 280
    px = (W - POPUP_W) // 2
    py = (H - POPUP_H) // 2

    # Shadow
    draw_popup_shadow(img, px, py, POPUP_W, POPUP_H)

    # Outer rounded rect
    draw2 = ImageDraw.Draw(img)
    rounded_rect(draw2, [px, py, px+POPUP_W, py+POPUP_H],
                 radius=12, fill=SURFACE, outline=DIVIDER, width=1)

    INNER_X = px + 14
    INNER_RIGHT = px + POPUP_W - 14
    y = py + 14

    if scenario == "settings":
        _draw_settings(img, draw2, px, py, POPUP_W, POPUP_H, INNER_X, INNER_RIGHT)
        return px, py, POPUP_W, POPUP_H

    # ── Header row ───────────────────────────────────────────────────
    fnt_icon = load_font(15, bold=True)
    fnt_title = load_font(15, bold=True)
    fnt_sm = load_font(12)
    fnt_xs = load_font(10)

    # Antenna icon
    for dx in [-4, -1, 2]:
        draw2.line([(INNER_X + 8 + dx, y + 3), (INNER_X + 8 + dx, y + 13)],
                   fill=RELAY_BLUE, width=1)
    draw2.ellipse([INNER_X + 5, y + 13, INNER_X + 13, y + 19], fill=RELAY_BLUE)

    # "Relay" wordmark
    draw2.text((INNER_X + 20, y + 1), "Relay", font=fnt_title, fill=TEXT)

    # Right icons (refresh + gear)
    icon_x = INNER_RIGHT - 14
    draw2.ellipse([icon_x - 8, y + 2, icon_x + 8, y + 18],
                  outline=TEXT_SEC, width=1)
    draw2.text((icon_x - 4, y + 4), "↻", font=fnt_sm, fill=TEXT_SEC)
    draw2.text((icon_x + 14, y + 3), "⚙", font=fnt_sm, fill=TEXT_SEC)

    y += 26

    # ── Gradient rule ────────────────────────────────────────────────
    gradient_line(img, INNER_X, y, INNER_RIGHT, thickness=2)
    y += 8

    # ── Stats bar ────────────────────────────────────────────────────
    fnt_stat = load_font(10)
    stats = [
        ("active", "2", RELAY_BLUE),
        ("pending", "12", TEXT_SEC),
        ("blocked", "1", RELAY_PINK),
        ("done", "4", "#30d158"),
    ]
    sx = INNER_X
    for label, val, color in stats:
        draw2.text((sx, y), val, font=load_font(12, bold=True), fill=color)
        vw = load_font(12, bold=True).getlength(val)
        draw2.text((sx + vw + 2, y + 2), label, font=fnt_stat, fill=TEXT_SEC)
        lw = fnt_stat.getlength(label)
        sx += vw + lw + 16

    y += 20

    # ── Divider ──────────────────────────────────────────────────────
    draw2.line([(INNER_X, y), (INNER_RIGHT, y)], fill=DIVIDER, width=1)
    y += 8

    if scenario in ("main", "blocked"):
        # ── ACTION NEEDED section ────────────────────────────────────
        fnt_sec = load_font(10, bold=True)
        draw2.text((INNER_X, y), "⚡ ACTION NEEDED", font=fnt_sec, fill=RELAY_PINK)
        y += 18

        tasks_action = [
            {
                "title": "Subscribe live Stripe webhook",
                "priority": ("urgent", BADGE_URGENT_BG, BADGE_URGENT_FG),
                "status": ("pending", BADGE_PENDING_BG, BADGE_PENDING_FG),
            },
            {
                "title": "Merge feat/lla-slice-2c → main",
                "priority": ("high", BADGE_HIGH_BG, BADGE_HIGH_FG),
                "status": ("pending", BADGE_PENDING_BG, BADGE_PENDING_FG),
            },
        ]
        for task in tasks_action:
            y = _draw_task_row(img, draw2, INNER_X, INNER_RIGHT, y, task,
                               border_color=RELAY_PINK)
            y += 6

        # ── Blocked action note (scenario 2 only) ───────────────────
        if scenario == "blocked":
            draw2.text((INNER_X, y), "⚡ Fix Stripe webhook before deploy can proceed",
                       font=fnt_stat, fill=RELAY_PINK)
            y += 16

        y += 4
        # ── IN PROGRESS section ──────────────────────────────────────
        draw2.text((INNER_X, y), "IN PROGRESS", font=fnt_sec, fill=RELAY_BLUE)
        y += 18

        task_inprog = {
            "title": "Lost Lead Audit Slice 2C — upgrade page",
            "priority": ("medium", BADGE_MED_BG, BADGE_MED_FG),
            "status": ("in_progress", BADGE_INPROG_BG, BADGE_INPROG_FG),
        }
        _draw_task_row(img, draw2, INNER_X, INNER_RIGHT, y, task_inprog,
                       border_color=RELAY_BLUE)

    # ── Overlay text for screenshot 2 ───────────────────────────────
    if show_overlay:
        overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
        od = ImageDraw.Draw(overlay)
        fnt_big = load_font(32, bold=True)
        msg = "Never miss a blocker"
        mw = fnt_big.getlength(msg)
        tx = (W - mw) // 2
        ty = py + POPUP_H + 28
        od.text((tx, ty), msg, font=fnt_big, fill=(242, 242, 247, 230))
        img.alpha_composite(overlay)

    return px, py, POPUP_W, POPUP_H


def _draw_task_row(img, draw, inner_x, inner_right, y, task, border_color=DIVIDER):
    """Draw a single task card row. Returns updated y."""
    row_h = 52
    rx0 = inner_x - 2
    rx1 = inner_right + 2
    # Card background
    draw.rounded_rectangle([rx0, y, rx1, y + row_h], radius=6,
                            fill=SURFACE2, outline=border_color, width=1)
    # Left accent bar
    draw.rounded_rectangle([rx0, y, rx0 + 3, y + row_h], radius=3,
                            fill=border_color)

    fnt_title = load_font(11, bold=True)
    fnt_badge = load_font(9)

    # Task title (truncate if needed)
    title = task["title"]
    max_w = (inner_right - inner_x) - 10
    while fnt_title.getlength(title) > max_w and len(title) > 10:
        title = title[:-4] + "…"
    draw.text((rx0 + 10, y + 8), title, font=fnt_title, fill=TEXT)

    # Badges
    bx = rx0 + 10
    by = y + 28
    p_label, p_bg, p_fg = task["priority"]
    bw, bh = draw_badge(draw, p_label, bx, by, p_bg, p_fg, fnt_badge)
    bx += bw + 6
    s_label, s_bg, s_fg = task["status"]
    draw_badge(draw, s_label, bx, by, s_bg, s_fg, fnt_badge)

    return y + row_h


def _draw_settings(img, draw, px, py, pw, ph, inner_x, inner_right):
    """Draw the Connect Relay settings panel."""
    y = py + 18

    fnt_title = load_font(16, bold=True)
    fnt_body = load_font(12)
    fnt_caption = load_font(10)
    fnt_btn = load_font(13, bold=True)

    draw.text((inner_x, y), "Connect Relay", font=fnt_title, fill=TEXT)
    y += 32

    # Token input field
    field_h = 36
    draw.rounded_rectangle([inner_x, y, inner_right, y + field_h],
                            radius=8, fill="#1c1c1e", outline=DIVIDER, width=1)
    draw.text((inner_x + 10, y + 10), "rt_xxxx...", font=fnt_body, fill=TEXT_SEC)
    y += field_h + 8

    # Caption
    caption = "Get your token at agent-task-tracker.onrender.com/get-started"
    # word-wrap manually at ~50 chars
    words = caption.split()
    line = ""
    lines = []
    for w in words:
        test = (line + " " + w).strip()
        if fnt_caption.getlength(test) > (inner_right - inner_x):
            lines.append(line)
            line = w
        else:
            line = test
    if line:
        lines.append(line)
    for ln in lines:
        draw.text((inner_x, y), ln, font=fnt_caption, fill=TEXT_SEC)
        y += 14
    y += 10

    # Connect button
    btn_w = inner_right - inner_x
    btn_h = 36
    draw.rounded_rectangle([inner_x, y, inner_x + btn_w, y + btn_h],
                            radius=8, fill=RELAY_BLUE)
    lbl = "Connect"
    lbl_w = fnt_btn.getlength(lbl)
    draw.text((inner_x + (btn_w - lbl_w) // 2, y + 8), lbl,
              font=fnt_btn, fill="#ffffff")


# ── Canvas builder ───────────────────────────────────────────────────
def make_canvas(W, H):
    """Dark gradient background."""
    img = Image.new("RGBA", (W, H), hex_to_rgb(BG) + (255,))
    draw = ImageDraw.Draw(img)
    # Subtle radial vignette (darker edges)
    from PIL import ImageFilter
    vignette = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vignette)
    vd.ellipse([-W//4, -H//4, W + W//4, H + H//4], fill=(0, 0, 0, 0))
    for i in range(40):
        alpha = int(i * 3)
        margin = i * 6
        vd.rectangle([margin, margin, W - margin, H - margin],
                     outline=(0, 0, 0, alpha), width=3)
    img.alpha_composite(vignette)
    draw = ImageDraw.Draw(img)
    return img, draw


# ── Screenshot 1 — Live task board ───────────────────────────────────
def screenshot_1(W, H):
    img, draw = make_canvas(W, H)
    draw_menubar(img, draw, W, icon_color=RELAY_BLUE, count_text="2")
    draw_popup(img, draw, W, H, scenario="main",
               icon_color=RELAY_BLUE, count_text="2")
    return img.convert("RGB")


# ── Screenshot 2 — Instant alerts / blocked state ────────────────────
def screenshot_2(W, H):
    img, draw = make_canvas(W, H)
    draw_menubar(img, draw, W, icon_color=RELAY_PINK, count_text="1")
    draw_popup(img, draw, W, H, scenario="blocked",
               icon_color=RELAY_PINK, count_text="1", show_overlay=True)
    return img.convert("RGB")


# ── Screenshot 3 — Zero setup / settings ────────────────────────────
def screenshot_3(W, H):
    img, draw = make_canvas(W, H)
    draw_menubar(img, draw, W, icon_color=RELAY_BLUE, count_text="")
    draw_popup(img, draw, W, H, scenario="settings")
    return img.convert("RGB")


# ── Main ─────────────────────────────────────────────────────────────
SIZES = [(1280, 800), (1440, 900)]
GENERATORS = [screenshot_1, screenshot_2, screenshot_3]

for idx, gen in enumerate(GENERATORS, start=1):
    for W, H in SIZES:
        img = gen(W, H)
        fname = f"screenshot_{idx}_{W}x{H}.png"
        path = os.path.join(OUT_DIR, fname)
        img.save(path, "PNG")
        print(f"Saved: {path}")

print("Done — 6 screenshots generated.")
