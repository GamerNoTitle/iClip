"""Create a macOS AppIcon asset catalog from the committed iconset."""
import json
import pathlib
import shutil
import sys

root = pathlib.Path(__file__).resolve().parents[1]
catalog = pathlib.Path(sys.argv[1])
appicon = catalog / 'AppIcon.appiconset'
appicon.mkdir(parents=True, exist_ok=True)
images = []
for size in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        name = f'icon_{size}x{size}' + ('@2x' if scale == 2 else '') + '.png'
        shutil.copyfile(root / 'Resources' / 'AppIcon.iconset' / name, appicon / name)
        images.append({'idiom': 'mac', 'size': f'{size}x{size}', 'scale': f'{scale}x', 'filename': name})
(appicon / 'Contents.json').write_text(json.dumps({'images': images, 'info': {'version': 1, 'author': 'xcode'}}))
(catalog / 'Contents.json').write_text(json.dumps({'info': {'version': 1, 'author': 'xcode'}}))
