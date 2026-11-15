import struct, zlib, sys
def parse(path):
    d = open(path, "rb").read()
    ver = struct.unpack("<I", d[23:27])[0]
    big = ver >= 7500
    def node(o):
        if big:
            end, nprops, plen = struct.unpack("<QQQ", d[o:o+24]); o += 24
        else:
            end, nprops, plen = struct.unpack("<III", d[o:o+12]); o += 12
        nl = d[o]; o += 1
        if end == 0: return None, o
        name = d[o:o+nl].decode(); o += nl
        props = []; p = o
        for _ in range(nprops):
            t = chr(d[p]); p += 1
            if t in "YCBIFDL":
                fmt = {"Y":"<h","C":"<b","B":"<b","I":"<i","F":"<f","D":"<d","L":"<q"}[t]
                sz = struct.calcsize(fmt); props.append(struct.unpack(fmt, d[p:p+sz])[0]); p += sz
            elif t in "fdlib":
                n, enc, cl = struct.unpack("<III", d[p:p+12]); p += 12
                raw = d[p:p+cl]; p += cl
                if enc: raw = zlib.decompress(raw)
                fmt = {"f":"f","d":"d","l":"q","i":"i","b":"b"}[t]
                props.append(list(struct.unpack("<%d%s" % (n, fmt), raw)))
            elif t in "SR":
                n = struct.unpack("<I", d[p:p+4])[0]; p += 4
                v = d[p:p+n]; p += n
                props.append(v.decode("utf8", "replace") if t == "S" else v)
        o += plen
        kids = []
        while o < end:
            k, o = node(o)
            if k is None: break
            kids.append(k)
        return (name, props, kids), end
    o = 27; top = []
    while o < len(d) - 200:
        n, o = node(o)
        if n is None: break
        top.append(n)
    return ver, top
def find(nodes, name): return [n for n in nodes if n[0] == name]
if __name__ == "__main__":
    for path in sys.argv[1:]:
        ver, top = parse(path)
        objs = find(top, "Objects")[0][2]
        from collections import Counter
        print("==", path.split("/")[-1][9:], ver, Counter(n[0] for n in objs))
        models = [(n[1][1].split("\x00")[0], n[1][2]) for n in objs if n[0] == "Model"]
        print(" models:", models[:70])
        print(" geometry:", [n[1][1].split("\x00")[0] for n in objs if n[0] == "Geometry"])
        for n in objs:
            if n[0] == "AnimationStack":
                print(" stack:", n[1][1].split("\x00")[0], [(p[1][0], p[1][4:]) for p in find(n[2], "Properties70")[0][2]])
        gs = find(top, "GlobalSettings")[0][2]
        print(" settings:", [(p[1][0], p[1][4:]) for p in find(gs, "Properties70")[0][2] if p[1][0] in ("UpAxis","FrontAxis","UnitScaleFactor","TimeMode","CustomFrameRate")])
