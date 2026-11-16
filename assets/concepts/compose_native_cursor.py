"""Composite the actual Windows pointer without changing its proportions.

Run with: uv run --with pillow python assets/concepts/compose_native_cursor.py
"""
from pathlib import Path
import struct
from PIL import Image

def native_cursor():
    resource = Path('C:/Windows/Cursors/aero_arrow.cur').read_bytes()
    entry = struct.unpack_from('<BBBBHHII', resource, 6)
    offset = entry[-1]
    header, width, double_height, planes, depth, *_ = struct.unpack_from('<IiiHHIIiiII', resource, offset)
    assert depth == 32
    height = double_height // 2
    # Pillow's CUR loader drops alpha; read the embedded BGRA bitmap.
    pixels = resource[offset + header:offset + header + width * height * 4]
    cursor = Image.frombytes('RGBA', (width, height), pixels, 'raw', 'BGRA')
    cursor = cursor.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    return cursor.crop(cursor.getbbox())

if __name__ == '__main__':
    folder = Path(__file__).resolve().parent
    cursor = native_cursor()
    cursor.save(folder / 'native-cursor-transparent.png')
    canvas = Image.open(folder / 'aqua-cross-clean.png').convert('RGBA')
    scale = canvas.height * 0.36 / cursor.height
    size = (round(cursor.width * scale), round(cursor.height * scale))
    assert abs(size[0] / size[1] - cursor.width / cursor.height) < 0.003
    cursor = cursor.resize(size, Image.Resampling.LANCZOS)
    canvas.alpha_composite(cursor, (round(canvas.width * 0.54), round(canvas.height * 0.47)))
    canvas.save(folder / 'aqua-pasted-cursor.png')
    canvas.resize((400, 400), Image.Resampling.LANCZOS).save(folder / 'aqua-pasted-cursor-preview.png')
    canvas.resize((32, 32), Image.Resampling.LANCZOS).resize((256, 256), Image.Resampling.NEAREST).save(folder / 'aqua-pasted-cursor-32px.png')
    print(f'Composited native cursor at {size[0]}x{size[1]}, with uniform scale {scale:.3f}.')
