"""
Generates a minimal but valid GLB (binary glTF 2.0) that represents a
solar panel:  1 m × 2 m flat box (2 cm thick) with a dark-blue/navy PBR
material — looks exactly like a monocrystalline solar panel from a distance.

Output: assets/models/solar_panel.glb
"""
import struct, json, math, os

# ── Geometry ──────────────────────────────────────────────────────────────────
# A box: W=1m, H=0.02m (flat panel), D=2m  centred at origin.
# 8 unique positions, 6 faces × 4 verts = 24 vertices (for normals + UVs)

W, H, D = 0.5, 0.01, 1.0   # half-extents

# face definitions: (normal, top-left, top-right, bot-right, bot-left)
faces = [
    # +Y top face (the solar panel surface shown to the sun)
    ([0, 1, 0],  [-W, H, -D], [W, H, -D], [W, H, D], [-W, H, D]),
    # -Y bottom
    ([0,-1, 0],  [-W,-H, D], [W,-H, D], [W,-H,-D], [-W,-H,-D]),
    # +X right
    ([1, 0, 0],  [W,-H,-D], [W, H,-D], [W, H, D], [W,-H, D]),
    # -X left
    ([-1,0, 0], [-W,-H, D],[-W, H, D],[-W, H,-D],[-W,-H,-D]),
    # +Z front
    ([0, 0, 1],  [-W,-H, D], [W,-H, D], [W, H, D], [-W, H, D]),
    # -Z back
    ([0, 0,-1],  [W,-H,-D],[-W,-H,-D],[-W, H,-D],[W, H,-D]),
]

positions, normals, uvs, indices = [], [], [], []
base = 0
for (n, tl, tr, br, bl) in faces:
    for v, u_coords in [(tl,(0,1)),(tr,(1,1)),(br,(1,0)),(bl,(0,0))]:
        positions.extend(v)
        normals.extend(n)
        uvs.extend(u_coords)
    indices += [base, base+1, base+2, base, base+2, base+3]
    base += 4

def pack_floats(lst):
    return struct.pack(f'{len(lst)}f', *lst)

def pack_ushorts(lst):
    return struct.pack(f'{len(lst)}H', *lst)

pos_bytes = pack_floats(positions)
nor_bytes = pack_floats(normals)
uv_bytes  = pack_floats(uvs)
idx_bytes = pack_ushorts(indices)

# Pad each buffer to 4-byte alignment
def pad4(b): return b + b'\x00' * ((-len(b)) % 4)

pos_bytes = pad4(pos_bytes)
nor_bytes = pad4(nor_bytes)
uv_bytes  = pad4(uv_bytes)
idx_bytes = pad4(idx_bytes)

# Bounding box
pos_list = [(positions[i], positions[i+1], positions[i+2])
            for i in range(0, len(positions), 3)]
min_xyz = [min(p[i] for p in pos_list) for i in range(3)]
max_xyz = [max(p[i] for p in pos_list) for i in range(3)]

# ── BIN blob layout ───────────────────────────────────────────────────────────
offsets, total = {}, 0
for name, blob in [('pos', pos_bytes),('nor', nor_bytes),('uv', uv_bytes),('idx', idx_bytes)]:
    offsets[name] = total
    total += len(blob)

bin_blob = pos_bytes + nor_bytes + uv_bytes + idx_bytes

# ── JSON (glTF ≥ 2.0) ─────────────────────────────────────────────────────────
gltf = {
    "asset": {"version": "2.0", "generator": "SolarSense AR builder"},
    "scene": 0,
    "scenes": [{"nodes": [0]}],
    "nodes": [{"mesh": 0}],
    "meshes": [{
        "name": "solar_panel",
        "primitives": [{
            "attributes": {
                "POSITION": 0,
                "NORMAL":   1,
                "TEXCOORD_0": 2,
            },
            "indices": 3,
            "material": 0,
        }]
    }],
    "accessors": [
        # 0 POSITION
        {"bufferView": 0, "byteOffset": 0, "componentType": 5126,
         "count": len(pos_list), "type": "VEC3",
         "min": min_xyz, "max": max_xyz},
        # 1 NORMAL
        {"bufferView": 1, "byteOffset": 0, "componentType": 5126,
         "count": len(pos_list), "type": "VEC3"},
        # 2 TEXCOORD_0
        {"bufferView": 2, "byteOffset": 0, "componentType": 5126,
         "count": len(pos_list), "type": "VEC2"},
        # 3 indices
        {"bufferView": 3, "byteOffset": 0, "componentType": 5123,
         "count": len(indices),  "type": "SCALAR"},
    ],
    "bufferViews": [
        {"buffer": 0, "byteOffset": offsets['pos'], "byteLength": len(pos_bytes)},
        {"buffer": 0, "byteOffset": offsets['nor'], "byteLength": len(nor_bytes)},
        {"buffer": 0, "byteOffset": offsets['uv'],  "byteLength": len(uv_bytes)},
        {"buffer": 0, "byteOffset": offsets['idx'], "byteLength": len(idx_bytes)},
    ],
    "buffers": [{"byteLength": total}],
    "materials": [{
        "name": "solar_panel_mat",
        "pbrMetallicRoughness": {
            # Dark blue — monocrystalline panel colour (sRGB #0a1a55)
            "baseColorFactor": [0.039, 0.102, 0.333, 1.0],
            "metallicFactor":  0.05,
            "roughnessFactor": 0.35,
        },
        "emissiveFactor": [0.0, 0.02, 0.08],  # slight blue edge glow
        "doubleSided": False,
    }]
}

json_bytes = json.dumps(gltf, separators=(',',':')).encode('utf-8')
json_bytes = pad4(json_bytes)

# ── GLB binary format ─────────────────────────────────────────────────────────
MAGIC   = 0x46546C67  # 'glTF'
VERSION = 2
CHUNK_JSON = 0x4E4F534A  # 'JSON'
CHUNK_BIN  = 0x004E4942  # 'BIN\0'

total_len = 12 + 8 + len(json_bytes) + 8 + len(bin_blob)

glb = struct.pack('<III', MAGIC, VERSION, total_len)
glb += struct.pack('<II', len(json_bytes), CHUNK_JSON) + json_bytes
glb += struct.pack('<II', len(bin_blob),   CHUNK_BIN)  + bin_blob

os.makedirs('assets/models', exist_ok=True)
out_path = 'assets/models/solar_panel.glb'
with open(out_path, 'wb') as f:
    f.write(glb)

print(f'Generated {out_path}  ({len(glb):,} bytes)')
print(f'  Vertices: {len(pos_list)}, Triangles: {len(indices)//3}')
