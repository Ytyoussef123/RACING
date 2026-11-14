#!/usr/bin/env python3
"""The game as the Android app carries it (android/app/src/main/assets/): everything it needs on the phone, nothing
fetched from the internet when it runs.

- game/index.html, its scripts from the CDNs replaced by local copies (lib/) taken from the npm package three@0.128.0
  (the same files: cdnjs's three.js r128 is the package's build/three.min.js, jsdelivr serves the package as it is),
  checked against the npm registry's own hash;
- the Google fonts (Saira Condensed, Rubik) copied into fonts/ (without them the game falls back to system fonts);
- the fullscreen buttons hidden: the app is fullscreen already;
- game/models/ as it is.

    python3 android/prepare_assets.py <repository> <assets dir>
"""
import base64, hashlib, io, json, os, re, shutil, sys, tarfile, urllib.request

THREE = '0.128.0'
UA = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Mobile Safari/537.36'


def get(url):
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def three_package():
    meta = json.loads(get(f'https://registry.npmjs.org/three/{THREE}'))
    data = get(meta['dist']['tarball'])
    algo, want = meta['dist']['integrity'].split('-', 1)
    if base64.b64encode(hashlib.new(algo, data).digest()).decode() != want:
        sys.exit('three.js package: hash mismatch')
    return tarfile.open(fileobj=io.BytesIO(data), mode='r:gz')


def main():
    repo, out = sys.argv[1], sys.argv[2]
    if os.path.exists(out):
        shutil.rmtree(out)
    os.makedirs(out)
    html = open(os.path.join(repo, 'game', 'index.html'), encoding='utf-8').read()

    # scripts: every https script of the page, from the npm package
    tar = three_package()
    def local(m):
        url = m.group(1)
        if url.startswith('https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/'):
            path = 'build/' + url.rsplit('/', 1)[1]
        elif url.startswith(f'https://cdn.jsdelivr.net/npm/three@{THREE}/'):
            path = url.split(f'three@{THREE}/', 1)[1]
        else:
            sys.exit('unknown script source: ' + url)
        dst = os.path.join(out, 'lib', path)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with tar.extractfile('package/' + path) as f, open(dst, 'wb') as g:
            g.write(f.read())
        return f'<script src="lib/{path}"></script>'
    html = re.sub(r'<script src="(https://[^"]+)"></script>', local, html)

    # fonts: the stylesheet and its font files, local
    m = re.search(r'<link rel="stylesheet" href="(https://fonts\.googleapis\.com/[^"]+)">', html)
    if m:
        try:
            css = get(m.group(1).replace('&amp;', '&')).decode()
            os.makedirs(os.path.join(out, 'fonts'))
            def font(u):
                name = hashlib.sha1(u.group(1).encode()).hexdigest()[:16] + '.woff2'
                open(os.path.join(out, 'fonts', name), 'wb').write(get(u.group(1)))
                return f'url({name})'
            css = re.sub(r'url\((https://[^)]+)\)', font, css)
            open(os.path.join(out, 'fonts', 'fonts.css'), 'w', encoding='utf-8').write(css)
            html = html.replace(m.group(0), '<link rel="stylesheet" href="fonts/fonts.css">')
        except Exception as e:                            # (the game's own fallback fonts then)
            print('fonts not copied:', e)
            html = html.replace(m.group(0), '')

    # the page has no document skeleton of its own (the artifact host adds one): the app's, with the phone's notch
    # covered (viewport-fit=cover), and no fullscreen buttons or note about them (the app is fullscreen already)
    if '<head' in html:
        sys.exit('the page now has its own <head>: update prepare_assets.py')
    html = ('<!doctype html>\n<html lang="fr"><head><meta charset="utf-8">\n'
            '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
            '<style>#fsBtn, #fsMenuBtn, #fsNote { display: none !important; }</style>\n'
            '</head><body>\n' + html + '\n</body></html>\n')

    left = re.findall(r'<(?:script|link)[^>]+(?:src|href)="https?://[^"]+"', html)
    if left:
        sys.exit('still fetched from the internet: ' + ', '.join(left))
    open(os.path.join(out, 'index.html'), 'w', encoding='utf-8').write(html)
    shutil.copytree(os.path.join(repo, 'game', 'models'), os.path.join(out, 'models'))
    size = sum(os.path.getsize(os.path.join(d, f)) for d, _, fs in os.walk(out) for f in fs)
    print(f'assets ready in {out}: {size / 1e6:.1f} MB')


if __name__ == '__main__':
    main()
