#!/usr/bin/env python3
"""Animated GIFs from captured frame series (showcase_capture's orbits and stills): every <prefix>_orbit_NNN.jpg or
<prefix>_still_NNN.jpg run in a folder becomes <prefix>_orbit.gif or <prefix>_still.gif, looping, at --fps (default
12); the frames are deleted with --clean. Needs Pillow (macOS's /usr/bin/python3 has it).

  /usr/bin/python3 tools/capture/frames_to_gif.py captures/showcase [--fps 12] [--clean]
"""
import glob, os, re, sys
from PIL import Image


def main(argv):
    folder = argv[0]
    fps = 12
    if '--fps' in argv:
        fps = int(argv[argv.index('--fps') + 1])
    series = {}
    for f in sorted(glob.glob(os.path.join(folder, '*_[0-9][0-9][0-9].jpg'))):
        m = re.match(r'(.*)_(orbit|still)_\d{3}\.jpg$', f)
        if m:
            series.setdefault(m.group(1) + '_' + m.group(2), []).append(f)
    for prefix, files in series.items():
        frames = [Image.open(f).convert('RGB').quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for f in files]
        out = prefix + '.gif'
        frames[0].save(out, save_all=True, append_images=frames[1:], duration=int(1000 / fps), loop=0, optimize=True)
        print('%s: %d frames, %.1f MB' % (out, len(frames), os.path.getsize(out) / 1e6))
        if '--clean' in argv:
            for f in files:
                os.remove(f)


if __name__ == '__main__':
    main(sys.argv[1:])
