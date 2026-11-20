"""Build a single-file copy of MotionForge with a character model embedded.

Usage: python3 build_embedded.py <model.fbx|glb> <output.html>

The embedded copy opens with that character already loaded (handy on a phone).
The model file itself is NOT committed to the repository (see README.md).
"""
import base64, json, pathlib, sys

src = pathlib.Path(__file__).with_name("motionforge.html")
model, out = map(pathlib.Path, sys.argv[1:3])
html = src.read_text(encoding="utf-8")
payload = json.dumps({"name": model.name, "b64": base64.b64encode(model.read_bytes()).decode()})
html = html.replace("<!--MF_EMBED-->", f"<script>window.MF_EMBEDDED_MODEL={payload};</script>", 1)
out.write_text(html, encoding="utf-8")
print(f"{out} ({out.stat().st_size // 1024} KB)")
