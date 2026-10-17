#!/usr/bin/env python3
"""Compile d3-celestial (BSD-3) JSON into one compact Zenith/Resources/sky.json."""
import json, pathlib
R = pathlib.Path(__file__).resolve().parent / "raw"
OUT = pathlib.Path(__file__).resolve().parents[1] / "Zenith/Resources/sky.json"
names = json.load(open(R/"starnames.json"))
stars = []
for f in json.load(open(R/"stars.6.json"))["features"]:
    m = f["properties"]["mag"]
    if m > 5.6: continue
    ra, dec = f["geometry"]["coordinates"]
    ra = ra % 360
    n = names.get(str(f["id"]), {}).get("name", "") or ""
    try: bv = float(f["properties"]["bv"])
    except Exception: bv = 0.6
    stars.append([round(ra, 3), round(dec, 3), round(m, 2), round(bv, 2), n])
cons = []
lines = {f["id"]: f["geometry"]["coordinates"] for f in json.load(open(R/"constellations.lines.json"))["features"]}
for f in json.load(open(R/"constellations.json"))["features"]:
    i = f["id"]; p = f["properties"]
    ra, dec = f["geometry"]["coordinates"]
    segs = [[[round(a % 360, 3), round(b, 3)] for a, b in seg] for seg in lines.get(i, [])]
    cons.append({"id": i, "name": p["en"] or p["name"], "ra": round(ra % 360, 2), "dec": round(dec, 2), "lines": segs})
json.dump({"stars": stars, "constellations": cons}, open(OUT, "w"), separators=(",", ":"))
print(len(stars), "stars", len(cons), "constellations", OUT.stat().st_size // 1024, "KB")
