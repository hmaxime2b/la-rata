from PIL import Image, ImageDraw, ImageFont
import os

def make_icon(size):
    img = Image.new('RGB', (size, size), color='#1B5E20')
    draw = ImageDraw.Draw(img)

    # Cercle de fond plus clair
    margin = int(size * 0.06)
    draw.ellipse([margin, margin, size - margin, size - margin],
                 fill='#2E7D32')

    # Rat emoji unicode text
    rat_size = int(size * 0.52)
    title_size = int(size * 0.13)

    try:
        rat_font = ImageFont.truetype("seguiemj.ttf", rat_size)
        title_font = ImageFont.truetype("arialbd.ttf", title_size)
    except:
        try:
            rat_font = ImageFont.truetype("C:/Windows/Fonts/seguiemj.ttf", rat_size)
            title_font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", title_size)
        except:
            rat_font = ImageFont.load_default()
            title_font = ImageFont.load_default()

    # Rat
    rat = "🐀"
    bbox = draw.textbbox((0, 0), rat, font=rat_font)
    rat_w = bbox[2] - bbox[0]
    rat_h = bbox[3] - bbox[1]
    rat_x = (size - rat_w) // 2 - bbox[0]
    rat_y = int(size * 0.12) - bbox[1]
    draw.text((rat_x, rat_y), rat, font=rat_font, fill='white')

    # "LA RATA" text
    title = "LA RATA"
    tbbox = draw.textbbox((0, 0), title, font=title_font)
    tw = tbbox[2] - tbbox[0]
    tx = (size - tw) // 2 - tbbox[0]
    ty = int(size * 0.80)
    draw.text((tx, ty), title, font=title_font, fill='#FFD700')

    return img

# Tailles requises pour Android
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
    img = make_icon(size)
    img.save(path)
    print(f"Generated {path} ({size}x{size})")

# 512x512 pour le Play Store
store_icon = make_icon(512)
store_icon.save(r'C:\Users\max20\la_rata\store_icon_512.png')
print("Generated store_icon_512.png (512x512) — upload this to Play Console")
