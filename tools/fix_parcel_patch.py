from pathlib import Path

# Follow-up patch is intentionally idempotent so CI can rerun it safely.
path = Path('MetroForge-2000.html')
text = path.read_text()
changes = 0

bad = "${n.water} need water.`}\n toast(s){"
good = "${n.water} need water.`}}\n toast(s){"
if bad in text:
    text = text.replace(bad, good, 1)
    changes += 1

old_consumer = "if(n)g.consumers.push({i,n})}"
new_consumer = "if(n)g.consumers.push({i,n,members:p?p.members:null})}"
if old_consumer in text:
    text = text.replace(old_consumer, new_consumer, 1)
    changes += 1

old_cover = "for(let c of g.consumers)if(left>=c.n){covered[c.i]=1;left-=c.n}}"
new_cover = "for(let c of g.consumers)if(left>=c.n){if(c.members)for(let j of c.members)covered[j]=1;else covered[c.i]=1;left-=c.n}}"
if old_cover in text:
    text = text.replace(old_cover, new_cover, 1)
    changes += 1

required = [
    'class ParcelSystem',
    "['apt','▥ Apartment lots']",
    'members:p?p.members:null',
    'if(c.members)for(let j of c.members)covered[j]=1',
]
missing = [token for token in required if token not in text]
if missing:
    raise SystemExit('Parcel follow-up validation failed; missing: ' + ', '.join(missing))

path.write_text(text)
print(f'Parcel follow-up fixes applied: {changes}')
