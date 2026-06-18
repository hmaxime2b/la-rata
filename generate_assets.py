from PIL import Image, ImageDraw, ImageFont
import os

FONT_PATHS = [
    "C:/Windows/Fonts/arialbd.ttf",
    "C:/Windows/Fonts/calibrib.ttf",
    "C:/Windows/Fonts/trebucbd.ttf",
    "C:/Windows/Fonts/verdanab.ttf",
]

def get_font(size):
    for fp in FONT_PATHS:
        try:
            return ImageFont.truetype(fp, size)
        except:
            continue
    return ImageFont.load_default()

def draw_heart(draw, cx, cy, s, color):
    r2 = s * 0.28
    lx, rx = cx - s * 0.25, cx + s * 0.25
    ty = cy - s * 0.15
    draw.ellipse([lx-r2, ty-r2, lx+r2, ty+r2], fill=color)
    draw.ellipse([rx-r2, ty-r2, rx+r2, ty+r2], fill=color)
    draw.polygon([
        (cx - s*0.52, cy - s*0.05),
        (cx + s*0.52, cy - s*0.05),
        (cx,          cy + s*0.46),
    ], fill=color)

# ─── ICÔNE 512×512 ────────────────────────────────────────────────────────────

def make_icon(size):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Fond vert uni avec coins arrondis
    r = int(size * 0.18)
    draw.rounded_rectangle([0, 0, size, size], radius=r, fill='#1B5E20')

    hcx = size * 0.5
    hcy = size * 0.56
    hs  = size * 0.72

    # Ombre
    draw_heart(draw, hcx + size*0.02, hcy + size*0.02, hs, '#7B0000')
    # Cœur principal
    draw_heart(draw, hcx, hcy, hs, '#E53935')
    # Reflet
    draw_heart(draw, hcx - size*0.01, hcy - size*0.01, hs * 0.88, '#EF5350')

    # K blanc
    k_size = int(size * 0.50)
    font = get_font(k_size)
    text = "K"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = (size - tw) // 2 - bbox[0]
    ty = int(size * 0.28) - bbox[1]

    draw.text((tx + size*0.025, ty + size*0.025), text, font=font, fill='#7B0000')
    draw.text((tx, ty), text, font=font, fill='white')

    return img.convert('RGB')

# ─── FEATURE GRAPHIC 1024×500 ─────────────────────────────────────────────────

def make_feature():
    W, H = 1024, 500
    img = Image.new('RGB', (W, H), '#1B5E20')
    draw = ImageDraw.Draw(img)

    # Fond dégradé vertical
    for y in range(H):
        t = y / H
        r = int(27  * (1-t) + 15 * t)
        g = int(94  * (1-t) + 60 * t)
        b = int(32  * (1-t) + 20 * t)
        draw.line([(0, y), (W, y)], fill=(r, g, b))

    # Cercle décoratif à droite
    draw.ellipse([W*0.58, -H*0.5, W*1.15, H*0.95], fill='#2E7D32')

    # === Cartes décoratives ===
    fv = get_font(20)
    fs = get_font(18)

    cards_data = [
        ('K', 'coeur',  640,  80,  10),
        ('Q', 'pique',  710, 100,  -8),
        ('A', 'coeur',  780,  70,   5),
        ('J', 'carreau',848,  95, -12),
    ]

    for val, suit_type, cx, cy, rot in cards_data:
        cw, ch = 100, 140
        card_img = Image.new('RGBA', (cw + 30, ch + 30), (0, 0, 0, 0))
        cd = ImageDraw.Draw(card_img)
        sym = '♥' if suit_type == 'coeur' else ('♠' if suit_type == 'pique' else ('♦' if suit_type == 'carreau' else '♣'))
        color = '#C62828' if suit_type in ('coeur', 'carreau') else '#212121'
        cd.rounded_rectangle([10, 10, cw+10, ch+10], radius=10, fill='white', outline='#cccccc', width=1)
        cd.text((18, 14), val, font=fv, fill=color)
        cd.text((18, 36), sym, font=fs, fill=color)
        big = get_font(48)
        bb = cd.textbbox((0, 0), sym, font=big)
        bx = (cw - (bb[2]-bb[0])) // 2 + 10 - bb[0]
        by = (ch - (bb[3]-bb[1])) // 2 + 10 - bb[1]
        cd.text((bx, by), sym, font=big, fill=color)
        rotated = card_img.rotate(rot, expand=True, resample=Image.BICUBIC)
        img.paste(rotated, (cx, cy), rotated)

    # === Icône à gauche ===
    icon_size = 190
    icon = make_icon(icon_size).convert('RGBA')
    mask = Image.new('L', (icon_size, icon_size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, icon_size, icon_size], radius=34, fill=255)
    icon.putalpha(mask)
    ix, iy = 55, H//2 - icon_size//2
    img.paste(icon, (ix, iy), icon)

    # === Texte ===
    title_font = get_font(86)
    sub_font   = get_font(28)
    tag_font   = get_font(21)

    tx = ix + icon_size + 30
    title = "La Rata"
    tb = draw.textbbox((0, 0), title, font=title_font)
    th = tb[3] - tb[1]
    ty_title = H // 2 - th // 2 - 35

    draw.text((tx + 3, ty_title + 3), title, font=title_font, fill=(0, 0, 0, 120))
    draw.text((tx, ty_title), title, font=title_font, fill='white')

    # Ligne décorative
    draw.rectangle([tx, ty_title + th + 6, tx + 270, ty_title + th + 9], fill='#81C784')

    # Sous-titre
    sub = "Le jeu de cartes Barbu"
    sb = draw.textbbox((0, 0), sub, font=sub_font)
    ty_sub = ty_title + th + 16
    draw.text((tx, ty_sub), sub, font=sub_font, fill='#A5D6A7')

    # Tags — chacun sur sa propre ligne pour éviter le chevauchement
    tags = ["3 niveaux", "7 contrats", "4 joueurs"]
    ty_tag = ty_sub + (sb[3]-sb[1]) + 18
    tx_tag = tx
    for tag in tags:
        bb = draw.textbbox((0, 0), tag, font=tag_font)
        tw2 = bb[2] - bb[0]
        pad = 12
        draw.rounded_rectangle([tx_tag - pad, ty_tag - 5, tx_tag + tw2 + pad, ty_tag + (bb[3]-bb[1]) + 5],
                                radius=12, fill='#2E7D32')
        draw.text((tx_tag - bb[0], ty_tag - bb[1]), tag, font=tag_font, fill='white')
        tx_tag += tw2 + pad*2 + 10

    return img

# ─── EXPORT ───────────────────────────────────────────────────────────────────

base = r'C:\Users\max20\la_rata'

icon = make_icon(512)
icon.save(os.path.join(base, 'store_icon_512.png'))
print("store_icon_512.png OK")

feature = make_feature()
feature.save(os.path.join(base, 'store_feature_1024x500.png'))
print("store_feature_1024x500.png OK")

sizes = {
    'mipmap-mdpi':    48,
    'mipmap-hdpi':    72,
    'mipmap-xhdpi':   96,
    'mipmap-xxhdpi':  144,
    'mipmap-xxxhdpi': 192,
}
res_base = os.path.join(base, 'android', 'app', 'src', 'main', 'res')
for folder, size in sizes.items():
    make_icon(size).save(os.path.join(res_base, folder, 'ic_launcher.png'))
    print(f"  {folder} ({size}px) OK")
