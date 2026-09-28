from pathlib import Path

path = Path('MetroForge-2000.html')
text = path.read_text()
bad = "${n.water} need water.`}\n toast(s){"
good = "${n.water} need water.`}}\n toast(s){"
if bad not in text:
    raise SystemExit('Expected parcel-status closing-brace target was not found')
path.write_text(text.replace(bad, good, 1))
print('Fixed parcel-status method closing brace.')
