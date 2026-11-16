"""Apply a subtle glass material inside the native cursor's unchanged silhouette."""
from pathlib import Path
import argparse
import math
from PIL import Image, ImageChops, ImageFilter, ImageOps
from compose_native_cursor import native_cursor

folder = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--background', default='aqua-cross-clean.png')
parser.add_argument('--output', default='aqua-glassy-native-cursor')
args = parser.parse_args()
canvas = Image.open(folder / args.background).convert('RGBA')
native = native_cursor()
scale = canvas.height * 0.46 / native.height
size = (round(native.width * scale), round(native.height * scale))
assert abs(size[0] / size[1] - native.width / native.height) < 0.003
cursor = native.resize(size, Image.Resampling.LANCZOS)
alpha = cursor.getchannel('A')
face = ImageChops.multiply(ImageOps.grayscale(cursor), alpha)
outline = ImageChops.subtract(alpha, face)
layer = Image.new('RGBA', size, (36, 32, 29, 0))
layer.putalpha(outline)

# The material is clipped to the actual cursor; neither axis nor its shape is warped.
glass = Image.new('RGBA', size)
pixels, mask = glass.load(), face.load()
for y in range(size[1]):
    t = y / max(1, size[1] - 1)
    color = (round(250 - 18 * t), round(252 - 18 * t), round(255 - 24 * t))
    opacity = 0.83 + 0.11 * abs(2 * t - 1)
    for x in range(size[0]):
        pixels[x, y] = (*color, round(mask[x, y] * opacity))
layer.alpha_composite(glass)

reflection = Image.new('L', size)
rp = reflection.load()
for y in range(size[1]):
    for x in range(size[0]):
        band = math.exp(-((y / size[1] + 0.16 * x / size[0] - 0.29) / 0.13) ** 2)
        rp[x, y] = round(mask[x, y] * band * 0.52)
shine = Image.new('RGBA', size, (255, 255, 255, 0))
shine.putalpha(reflection)
layer.alpha_composite(shine)

for offset, color, strength in [((7, 7), (255, 255, 255), 0.90), ((-7, -7), (99, 122, 140), 0.45)]:
    shifted = Image.new('L', size)
    shifted.paste(face, offset)
    edge = ImageChops.subtract(face, shifted).point(lambda value: round(value * strength))
    rim = Image.new('RGBA', size, (*color, 0))
    rim.putalpha(edge)
    layer.alpha_composite(rim)

position = (round(canvas.width * 0.52), round(canvas.height * 0.39))
shadow_mask = Image.new('L', canvas.size)
shadow_mask.paste(alpha, (position[0] + 5, position[1] + 7))
shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(5)).point(lambda value: round(value * 0.30))
shadow = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
shadow.putalpha(shadow_mask)
canvas.alpha_composite(shadow)
canvas.alpha_composite(layer, position)
canvas.save(folder / f'{args.output}.png')
canvas.resize((400, 400), Image.Resampling.LANCZOS).save(folder / f'{args.output}-preview.png')
canvas.resize((32, 32), Image.Resampling.LANCZOS).resize((256, 256), Image.Resampling.NEAREST).save(folder / f'{args.output}-32px.png')
print(f'Native cursor enlarged from 36% to 46% of icon height, uniformly scaled to {size}.')
