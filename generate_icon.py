from PIL import Image, ImageDraw, ImageFont
import os

def make_icon(size):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Fond vert foncé avec coins arrondis
    r = int(size * 0.18)
    draw.rounded_rectangle([0, 0, size, size], radius=r, fill='#1B5E20')

    # Cœur rouge — dessiné avec deux cercles + triangle
    def draw_heart(cx, cy, heart_size, color):
        s = heart_size
        # Deux cercles du haut
        left_cx  = cx - s * 0.25
        right_cx = cx + s * 0.25
        top_cy   = cy - s * 0.15
        r2 = s * 0.28
        draw.ellipse([left_cx  - r2, top_cy - r2, left_cx  + r2, top_cy + r2], fill=color)
        draw.ellipse([right_cx - r2, top_cy - r2, right_cx + r2, top_cy + r2], fill=color)
        # Triangle bas
        draw.polygon([
            (cx - s * 0.52, cy - s * 0.05),
            (cx + s * 0.52, cy - s * 0.05),
            (cx,            cy + s * 0.46),
        ], fill=color)

    heart_cx = size * 0.5
    heart_cy = size * 0.54
    heart_size = size * 0.72

    # Ombre légère
    draw_heart(heart_cx + size*0.02, heart_cy + size*0.02, heart_size, '#7B0000')
    # Cœur principal
    draw_heart(heart_cx, heart_cy, heart_size, '#E53935')
    # Reflet
    draw_heart(heart_cx - size*0.01, heart_cy - size*0.01, heart_size * 0.88, '#EF5350')

    # "K" blanc centré sur le cœur
    k_size = int(size * 0.48)
    font = None
    font_paths = [
        "C:/Windows/Fonts/arialbd.ttf",
        "C:/Windows/Fonts/Arial Bold.ttf",
        "C:/Windows/Fonts/calibrib.ttf",
        "C:/Windows/Fonts/trebucbd.ttf",
    ]
    for fp in font_paths:
        try:
            font = ImageFont.truetype(fp, k_size)
            break
        except:
            continue
    if font is None:
        font = ImageFont.load_default()

    text = "K"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (size - tw) // 2 - bbox[0]
    ty = int(size * 0.31) - bbox[1]

    # Ombre du K
    draw.text((tx + size*0.02, ty + size*0.02), text, font=font, fill='#B71C1C')
    # K blanc
    draw.text((tx, ty), text, font=font, fill='white')

    return img.convert('RGB')

sizes = {
    'mipmap-mdpi':    48,
    'mipmap-hdpi':    72,
    'mipmap-xhdpi':   96,
    'mipmap-xxhdpi':  144,
    'mipmap-xxxhdpi': 192,
}

base = r'C:\Users\max20\la_rata\android\app\src\main\res'

for folder, size in sizes.items():
    path = os.path.join(base, folder, 'ic_launcher.png')
    make_icon(size).save(path)
    print(f"Generated {size}x{size} - {folder}")

store = make_icon(512)
store.save(r'C:\Users\max20\la_rata\store_icon_512.png')
print("Generated store_icon_512.png (512x512)")
