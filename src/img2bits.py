
import os
import sys
from PIL import Image


def convert_image(file_name):
    img = Image.open(file_name).convert('L')

    name = os.path.splitext(os.path.basename(file_name))[0]
    print(f'; {img.size[0]}x{img.size[1]}')
    print(f'img_{name}:')

    
    data = list(img.getdata())
    nbytes = len(data) // 8 + 1 if (len(data) % 8) else 0

    for bt in [data[n * 8 : n * 8 + 8] for n in range(nbytes)]:
        str_byte = ''.join(['0' if pixel > 0 else '1' for pixel in bt])
        
        if len(str_byte) < 8:
            str_byte = str_byte + '0' * (8 - len(str_byte))

        str_byte = f'    .byte 0b{str_byte}'

        print(str_byte)


if __name__ == '__main__':
    for fn in sys.argv[1:]:
        print('\n')
        convert_image(fn)
