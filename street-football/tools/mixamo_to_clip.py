#!/usr/bin/env python3
"""Turns a Mixamo animation (binary FBX) into a pose clip for the jointed body (RigPose channels).

    python3 tools/mixamo_to_clip.py <animation.fbx> <data/animations/name.json> [seconds_before] [seconds_after]

The clip is cut around the kick (the frame where a foot moves fastest): seconds_before the contact
and seconds_after it, mirrored if needed so the kicking foot is the right one. Only joint angles
are kept (the FBX and its character are not shipped). Needs numpy.
"""
import json, math, sys
import numpy as np
from fbx_parse import parse, find

FBX_SECOND = 46186158000
FPS = 30
CH = ["ROOT_Y", "ROOT_FWD", "ROOT_X", "ROOT_Z", "HIPS_Y", "HIPS_Z", "SPINE_X", "SPINE_Y", "SPINE_Z", "NECK_X",
      "THIGH_L_X", "THIGH_L_Z", "KNEE_L", "THIGH_R_X", "THIGH_R_Z", "KNEE_R",
      "ARM_L_X", "ARM_L_Z", "ELBOW_L", "ARM_R_X", "ARM_R_Z", "ELBOW_R"]
I = {n: i for i, n in enumerate(CH)}
OUR_HEIGHT = 1.75


def rot(axis, deg):
    a = math.radians(deg); c, s = math.cos(a), math.sin(a)
    if axis == 0: return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
    if axis == 1: return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def euler(v):  # FBX default order XYZ: R = Rz * Ry * Rx
    return rot(2, v[2]) @ rot(1, v[1]) @ rot(0, v[0])


def load(path):
    _, top = parse(path)
    objs = find(top, "Objects")[0][2]
    models, curve_nodes, curves, stacks = {}, {}, {}, {}
    for n in objs:
        uid = n[1][0]
        if n[0] == "Model":
            props = {p[1][0]: p[1][4:] for p in find(n[2], "Properties70")[0][2]}
            models[uid] = {"name": n[1][1].split("\x00")[0].split(":")[-1], "t": props.get("Lcl Translation", [0, 0, 0]),
                           "r": props.get("Lcl Rotation", [0, 0, 0]), "pre": props.get("PreRotation", [0, 0, 0]),
                           "parent": None, "anim": {}}
        elif n[0] == "AnimationCurveNode":
            curve_nodes[uid] = {}
        elif n[0] == "AnimationCurve":
            curves[uid] = (find(n[2], "KeyTime")[0][1][0], find(n[2], "KeyValueFloat")[0][1][0])
        elif n[0] == "AnimationStack":
            props = {p[1][0]: p[1][4:] for p in find(n[2], "Properties70")[0][2]}
            stacks[n[1][1].split("\x00")[0]] = props.get("LocalStop", [0])[0]
    for c in find(top, "Connections")[0][2]:
        kind, child, parent = c[1][0], c[1][1], c[1][2]
        if kind == "OO" and child in models and parent in models:
            models[child]["parent"] = parent
        elif kind == "OP" and child in curve_nodes and parent in models:
            models[parent]["anim"][c[1][3]] = curve_nodes[child]
        elif kind == "OP" and child in curves and parent in curve_nodes:
            curve_nodes[parent][c[1][3]] = curves[child]
    return models, max(stacks.values()) / FBX_SECOND


def sample(node, prop, base, t):
    out = list(base)
    for k, axis in (("d|X", 0), ("d|Y", 1), ("d|Z", 2)):
        if prop in node["anim"] and k in node["anim"][prop]:
            times, values = node["anim"][prop][k]
            out[axis] = float(np.interp(t * FBX_SECOND, times, values))
    return out


def world(models, t):
    done = {}
    def get(uid):
        if uid in done: return done[uid]
        m = models[uid]
        R = euler(m["pre"]) @ euler(sample(m, "Lcl Rotation", m["r"], t))
        T = np.array(sample(m, "Lcl Translation", m["t"], t))
        if m["parent"] is not None:
            PR, PT = get(m["parent"])
            R, T = PR @ R, PT + PR @ T
        done[uid] = (R, T)
        return done[uid]
    return {models[u]["name"]: get(u) for u in models}


def unit(v):
    return v / max(1e-9, np.linalg.norm(v))


def angle(a, b):
    return math.acos(max(-1.0, min(1.0, float(np.dot(unit(a), unit(b))))))


def limb(d):  # direction of a hanging limb in its parent's frame -> (x, z) joint angles
    return math.atan2(-d[2], -d[1]), math.asin(max(-1.0, min(1.0, d[0])))


def frame_pose(w, scale, stand):
    P = lambda n: w[n][1]
    v = [0.0] * len(CH)
    H = w["Hips"][0]
    yaw = math.atan2(H[0, 2], H[2, 2])
    Hl = rot(1, -math.degrees(yaw)) @ H  # lean and roll left once the turn is taken out
    v[I["ROOT_X"]] = math.asin(max(-1.0, min(1.0, Hl[2, 1])))
    v[I["ROOT_Z"]] = math.atan2(-Hl[0, 1], Hl[1, 1])
    v[I["HIPS_Y"]] = yaw
    v[I["ROOT_Y"]] = (P("Hips")[1] - stand) * scale
    Hi = H.T
    up = unit(Hi @ (P("Neck") - P("Spine")))
    v[I["SPINE_X"]] = math.atan2(up[2], up[1])
    v[I["SPINE_Z"]] = -math.asin(max(-1.0, min(1.0, up[0])))
    across = Hi @ (P("LeftArm") - P("RightArm"))
    v[I["SPINE_Y"]] = math.atan2(-across[2], across[0])
    for side, s in (("Left", "L"), ("Right", "R")):
        x, z = limb(unit(Hi @ (P(side + "Leg") - P(side + "UpLeg"))))
        v[I["THIGH_%s_X" % s]], v[I["THIGH_%s_Z" % s]] = x, z
        v[I["KNEE_%s" % s]] = angle(P(side + "Leg") - P(side + "UpLeg"), P(side + "Foot") - P(side + "Leg"))
    # Chest frame: up along the spine, left across the shoulders, forward = left x up.
    cu = unit(P("Neck") - P("Spine"))
    cl = P("LeftArm") - P("RightArm"); cl = unit(cl - cu * np.dot(cl, cu))
    C = np.stack([cl, cu, np.cross(cl, cu)])
    for side, s in (("Left", "L"), ("Right", "R")):
        x, z = limb(unit(C @ (P(side + "ForeArm") - P(side + "Arm"))))
        v[I["ARM_%s_X" % s]], v[I["ARM_%s_Z" % s]] = x, z
        v[I["ELBOW_%s" % s]] = -angle(P(side + "ForeArm") - P(side + "Arm"), P(side + "Hand") - P(side + "ForeArm"))
    return v


def mirror(v):
    out = list(v)
    for a, b in (("THIGH_L_X", "THIGH_R_X"), ("KNEE_L", "KNEE_R"), ("ARM_L_X", "ARM_R_X"), ("ELBOW_L", "ELBOW_R")):
        out[I[a]], out[I[b]] = v[I[b]], v[I[a]]
    for a, b in (("THIGH_L_Z", "THIGH_R_Z"), ("ARM_L_Z", "ARM_R_Z")):
        out[I[a]], out[I[b]] = -v[I[b]], -v[I[a]]
    for n in ("ROOT_Z", "HIPS_Y", "HIPS_Z", "SPINE_Y", "SPINE_Z"):
        out[I[n]] = -v[I[n]]
    return out


def main():
    src, dst = sys.argv[1], sys.argv[2]
    before = float(sys.argv[3]) if len(sys.argv) > 3 else 0.1
    after = float(sys.argv[4]) if len(sys.argv) > 4 else 0.5
    models, length = load(src)
    count = int(length * FPS) + 1
    worlds = [world(models, i / FPS) for i in range(count)]
    w0 = worlds[0]
    scale = OUR_HEIGHT / (w0["HeadTop_End"][1][1] - min(w0["LeftToeBase"][1][1], w0["RightToeBase"][1][1]))
    stand = max(w["Hips"][1][1] for w in worlds[:max(2, count // 6)])
    # Contact: the frame where a foot moves fastest relative to the hips.
    best, contact, foot = 0.0, 0, "Right"
    for i in range(1, count):
        for side in ("Left", "Right"):
            rel = lambda w: w[side + "Foot"][1] - w["Hips"][1]
            speed = np.linalg.norm(rel(worlds[i]) - rel(worlds[i - 1])) * FPS * scale
            if speed > best: best, contact, foot = speed, i, side
    first = max(0, contact - int(round(before * FPS)))
    last = min(count - 1, contact + int(round(after * FPS)))
    yaw0 = None
    frames = []
    for i in range(first, last + 1):
        v = frame_pose(worlds[i], scale, stand)
        if foot == "Left": v = mirror(v)
        frames.append(v)
    yaw0 = frames[contact - first][I["HIPS_Y"]]
    for v in frames:
        v[I["HIPS_Y"]] = math.atan2(math.sin(v[I["HIPS_Y"]] - yaw0), math.cos(v[I["HIPS_Y"]] - yaw0))
    clip = {"_source": "Mixamo animation (mixamo.com, free for use in games), joint angles only, converted by tools/mixamo_to_clip.py",
            "fps": FPS, "contact": contact - first, "channels": CH,
            "frames": [[round(x, 3) for x in v] for v in frames]}
    with open(dst, "w") as f:
        f.write(json.dumps(clip).replace("], [", "],\n[").replace('"frames": [[', '"frames": [\n[') + "\n")
    print("%s: %.2f s, %d frames, contact at frame %d (%s foot, %.1f m/s), kept %d..%d" % (dst, length, count, contact, foot, best, first, last))


main()
