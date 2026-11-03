#!/usr/bin/env python3
"""Measure intervals between app-attributed presentation timestamps in an xctrace export."""
import argparse
import hashlib
import json
import math
import re
from pathlib import Path
import xml.etree.ElementTree as ET


def summarize(toc, data, run, start, end):
    tables = ET.parse(toc).findall(f"./run[@number='{run}']/data/table")
    root = ET.parse(data).getroot()
    refs = {e.get("id"): e for e in root.iter() if e.get("id")}
    application = set()
    lifetimes = {}

    def cell(row, index):
        element = row[index]
        return refs[element.attrib["ref"]] if "ref" in element.attrib else element

    for node in root.findall("node"):
        match = re.search(r"/run\[(\d+)\]/data\[1\]/table\[(\d+)\]", node.attrib["xpath"])
        if not match or int(match[1]) != run:
            continue
        schema = tables[int(match[2]) - 1].get("schema")
        for row in node.findall("row"):
            if schema == "hitches-updates" and cell(row, 2).get("fmt", "").startswith("StreamLab (") and cell(row, 7).text == "0":
                application.add(tuple(cell(row, i).text for i in (3, 4, 5)))
            elif schema == "hitches-frame-lifetimes":
                key = tuple(cell(row, i).text for i in (2, 3, 4))
                presentation = int(cell(row, 0).text) + int(cell(row, 1).text)
                if key in lifetimes and lifetimes[key] != presentation:
                    raise ValueError("Ambiguous lifetime for display, swap and surface")
                lifetimes[key] = presentation
    if not application or application - lifetimes.keys():
        raise ValueError("Missing lifetime match for one or more app frames")
    frames = {key: lifetimes[key] for key in application if start * 1e9 <= lifetimes[key] < end * 1e9}
    if len({key[0] for key in frames}) != 1:
        raise ValueError("Expected one display in the selected window")
    stamps = sorted(set(frames.values()))
    if len(stamps) < 2:
        raise ValueError("Fewer than two app presentations in the selected window")
    gaps = sorted(b - a for a, b in zip(stamps, stamps[1:]))

    def ms(p):
        return gaps[math.ceil(len(gaps) * p) - 1] / 1e6
    return dict(run=run, window_s=[start, end], frames=len(stamps), intervals=len(gaps),
                first_s=stamps[0]/1e9, last_s=stamps[-1]/1e9, p50_ms=ms(.5), p95_ms=ms(.95),
                max_ms=ms(1), toc_sha256=hashlib.sha256(toc.read_bytes()).hexdigest(),
                export_sha256=hashlib.sha256(data.read_bytes()).hexdigest())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("toc", "data"):
        parser.add_argument(name, type=Path)
    parser.add_argument("--run", type=int, required=True)
    parser.add_argument("--start", type=float, required=True)
    parser.add_argument("--end", type=float, required=True)
    args = parser.parse_args()
    print(json.dumps(summarize(**vars(args)), indent=2))
