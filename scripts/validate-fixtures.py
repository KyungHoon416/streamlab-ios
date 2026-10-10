#!/usr/bin/env python3
import json
from pathlib import Path
p=Path(__file__).resolve().parent.parent/'Packages/StreamLabCore/Sources/StreamLabCatalogData/Resources/catalog.json'
items=json.loads(p.read_text(encoding='utf-8'))
assert len(items)==2000, len(items)
assert len({x['id'] for x in items})==2000
assert all(x['rating'] in ('ALL','7+','12+','15+','19+') for x in items)
print('OK: 2,000 unique original catalog records, valid ratings')
