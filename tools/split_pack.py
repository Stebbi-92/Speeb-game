"""Splits the game's data into parts, so an update fetches only what changed.

A Godot pack (.pck) holds every file of the game. Most of its 550 MB is models, textures and sound,
which few releases change. This cuts a full pack into
  - a code pack: scripts, scenes, project settings and everything not in a part (a few tens of MB), and
  - one pack per part (arms, foes, world models, textures, sound), each named for what went into it.

A part's name carries a hash of its source files in git (and of what turns them into game data: the
Godot version, the platform and the import settings), so a part whose sources did not change keeps its
name from release to release, and a player who has it already never fetches it again.

  python3 tools/split_pack.py plan                    -> parts.json (in the project: goes into every pack)
  python3 tools/split_pack.py split FULL.pck OS OUT   -> OUT/<code pack> and OUT/<part packs>, OUT/<manifest>
  python3 tools/split_pack.py reuse NEW.json OLD.json OLD_TAG
      -> parts NEW shares by name with the last release are pointed at that release (written into NEW),
         and their names printed: those need not be uploaded again

The game reads parts.json (scripts/updater.gd): a code pack holds a marker file, res://.code_pack, and on
starting from one the game loads the parts it names before anything else.
"""
import hashlib, json, os, struct, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENGINE = "godot4.3"
LIBS = "rtc1"        # keep in step with Updater.LIBS and tools/release.sh
EPOCH = "1"          # raise to make every part new (a change in how parts are made)
# Part: the source folders it holds, first match wins (so "world" takes the models the others leave)
PARTS = [
	("arms", ["assets/models/arms/", "assets/models/hands/"]),
	("foes", ["assets/models/foes/"]),
	("world", ["assets/models/"]),
	("textures", ["assets/textures/"]),
	("sound", ["assets/audio/", "assets/music/"]),
]
MARKER = "res://.code_pack"


def part_of(src):
	"""The part a source path (res://...) belongs in, or None for the code pack."""
	rel = src[len("res://"):] if src.startswith("res://") else src
	for name, prefixes in PARTS:
		if any(rel.startswith(p) for p in prefixes):
			return name
	return None


def source_hashes(os_name):
	"""{part: 12-hex hash} from the git blobs of each part's files, plus what makes them game data."""
	out = subprocess.run(["git", "ls-files", "-s", "--", "assets"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
	blobs = {}
	for line in out.splitlines():
		meta, path = line.split("\t", 1)
		p = part_of(path)
		if p:
			blobs.setdefault(p, []).append("%s %s" % (meta.split()[1], path))
	settings = []
	for line in open(os.path.join(ROOT, "project.godot")):
		if line.startswith(("rendering/textures", "importer", "rendering/vram", "textures/")):
			settings.append(line.strip())
	hashes = {}
	for name, _ in PARTS:
		h = hashlib.sha256()
		h.update(("%s|%s|%s|%s|%s\n" % (EPOCH, ENGINE, LIBS, os_name, name)).encode())
		h.update("\n".join(settings).encode())
		h.update("\n".join(sorted(blobs.get(name, []))).encode())
		if name in os.environ.get("SPLIT_TEST_CHANGED", "").split(","):
			h.update(b"changed for a test")   # tools/update_test.sh: as if this part's sources changed
		hashes[name] = h.hexdigest()[:12]
	return hashes


def part_file(os_name, part, h):
	return "Brelm-%s-%s-%s-%s-%s.pck" % (os_name, ENGINE, LIBS, part, h)


def code_file(os_name):
	return "Brelm-%s-%s-%s-code.pck" % (os_name, ENGINE, LIBS)


def manifest_file(os_name):
	return "Brelm-%s-%s-%s-parts.json" % (os_name, ENGINE, LIBS)


OSES = ["Windows", "Linux", "macOS"]


def plan_all():
	"""What each platform's parts are: res://parts.json, in every pack, so a game knows its own parts."""
	return {o: plan(o) for o in OSES}


def plan(os_name):
	hs = source_hashes(os_name)
	return {"os": os_name, "engine": ENGINE, "libs": LIBS,
		"parts": [{"part": n, "name": part_file(os_name, n, hs[n])} for n, _ in PARTS]}


# ------------------------------------------------------------------ the pack format (Godot 4.3, version 2)

ALIGN = 16


def read_pack(path):
	f = open(path, "rb")
	head = f.read(100)
	magic, fmt, ma, mi, pa, flags, base = struct.unpack("<IIIIIIQ", head[:32])
	if magic != 0x43504447 or fmt != 2:
		sys.exit("%s: not a Godot 4 pack" % path)
	if flags & 1:
		sys.exit("%s: encrypted packs cannot be split" % path)
	count = struct.unpack("<I", head[96:100])[0]
	files = []
	for _ in range(count):
		n = struct.unpack("<I", f.read(4))[0]
		name = f.read(n).rstrip(b"\0").decode("utf-8")
		off, size = struct.unpack("<QQ", f.read(16))
		md5 = f.read(16)
		fl = struct.unpack("<I", f.read(4))[0]
		files.append({"path": name, "off": off, "size": size, "md5": md5, "flags": fl})
	return f, (ma, mi, pa), base, files


def write_pack(path, version, items):
	"""items: [(res path, bytes or (file, offset, size), md5 or None)]"""
	def padded(s):
		b = s.encode("utf-8")
		return b + b"\0" * ((4 - len(b) % 4) % 4)
	dir_size = 100 + sum(4 + len(padded(p)) + 16 + 16 + 4 for p, _, _ in items)
	base = dir_size + (-dir_size) % ALIGN
	entries, off = [], 0
	for p, data, md5 in items:
		size = len(data) if isinstance(data, (bytes, bytearray)) else data[2]
		entries.append((p, off, size, md5))
		off += size + (-size) % ALIGN
	with open(path, "wb") as o:
		o.write(struct.pack("<IIIIIIQ", 0x43504447, 2, version[0], version[1], version[2], 0, base))
		o.write(b"\0" * 64)
		o.write(struct.pack("<I", len(items)))
		for (p, data, md5), (_, eoff, size, _) in zip(items, entries):
			pb = padded(p)
			if md5 is None:
				md5 = hashlib.md5(data).digest()
			o.write(struct.pack("<I", len(pb)) + pb + struct.pack("<QQ", eoff, size) + md5 + struct.pack("<I", 0))
		o.write(b"\0" * (base - o.tell()))
		for (p, data, md5), (_, eoff, size, _) in zip(items, entries):
			assert o.tell() == base + eoff
			if isinstance(data, (bytes, bytearray)):
				o.write(data)
			else:
				src, soff, n = data
				src.seek(soff)
				while n > 0:
					chunk = src.read(min(n, 1 << 22))
					o.write(chunk)
					n -= len(chunk)
			o.write(b"\0" * ((-size) % ALIGN))


def remap_targets(text):
	"""The files a .import or .remap points to: every path="..." / path.xxx="..." line."""
	out = []
	for line in text.splitlines():
		k, _, v = line.partition("=")
		if (k == "path" or k.startswith("path.")) and v.startswith('"res://'):
			out.append(v.strip('"'))
	return out


def sha256_of(path):
	h = hashlib.sha256()
	with open(path, "rb") as f:
		for chunk in iter(lambda: f.read(1 << 22), b""):
			h.update(chunk)
	return h.hexdigest()


def split(full, os_name, out_dir):
	f, version, base, files = read_pack(full)
	by_path = {e["path"]: e for e in files}
	owner = {}    # res path -> part
	for e in files:
		p = e["path"]
		src = p[: -len(".import")] if p.endswith(".import") else p[: -len(".remap")] if p.endswith(".remap") else p
		part = part_of(src)
		if part is None:
			continue
		owner[p] = part
		if p.endswith((".import", ".remap")):
			f.seek(base + e["off"])
			for t in remap_targets(f.read(e["size"]).decode("utf-8", "replace")):
				if t in by_path:
					owner[t] = part
	pl = plan(os_name)
	names = {x["part"]: x["name"] for x in pl["parts"]}
	os.makedirs(out_dir, exist_ok=True)
	groups = {}
	for e in files:
		groups.setdefault(owner.get(e["path"]), []).append(e)
	# The code pack: all the rest, with the plan and the marker that says parts must be loaded
	code = [(e["path"], (f, base + e["off"], e["size"]), e["md5"]) for e in groups.get(None, []) if e["path"] not in ("res://parts.json", MARKER)]
	code.append(("res://parts.json", json.dumps(plan_all(), indent=1).encode(), None))
	code.append((MARKER, b"1", None))
	code.sort(key=lambda x: x[0])
	write_pack(os.path.join(out_dir, code_file(os_name)), version, code)
	man = {"os": os_name, "engine": ENGINE, "libs": LIBS, "parts": []}
	cp = os.path.join(out_dir, code_file(os_name))
	man["code"] = {"name": code_file(os_name), "size": os.path.getsize(cp), "sha256": sha256_of(cp)}
	for name, _ in PARTS:
		items = [(e["path"], (f, base + e["off"], e["size"]), e["md5"]) for e in groups.get(name, [])]
		path = os.path.join(out_dir, names[name])
		write_pack(path, version, sorted(items, key=lambda x: x[0]))
		man["parts"].append({"part": name, "name": names[name], "size": os.path.getsize(path), "sha256": sha256_of(path), "files": len(items)})
	with open(os.path.join(out_dir, manifest_file(os_name)), "w") as m:
		json.dump(man, m, indent=1)
	total = sum(x["size"] for x in man["parts"])
	print("split %s: code %.1f MB, parts %s" % (os_name, man["code"]["size"] / 1e6,
		", ".join("%s %.0f MB" % (x["part"], x["size"] / 1e6) for x in man["parts"])))
	return man


def reuse(new_path, old_path, old_tag):
	new = json.load(open(new_path))
	try:
		old = json.load(open(old_path))
	except (OSError, ValueError):
		old = {"parts": []}
	had = {p["name"]: p for p in old.get("parts", [])}
	home = "https://github.com/Stebbi-92/Speeb-game/releases/download/"
	for p in new["parts"]:
		o = had.get(p["name"])
		if not o or not old_tag:
			continue
		# The file already published under this name: its own size and hash, from where it lies
		p["url"] = o.get("url") or home + old_tag + "/" + p["name"]
		p["size"] = o["size"]
		p["sha256"] = o["sha256"]
		print(p["name"])
	json.dump(new, open(new_path, "w"), indent=1)


if __name__ == "__main__":
	if len(sys.argv) >= 2 and sys.argv[1] == "plan":
		with open(os.path.join(ROOT, "parts.json"), "w") as o:
			json.dump(plan_all(), o, indent=1)
	elif len(sys.argv) >= 4 and sys.argv[1] == "reuse":
		reuse(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "")
	elif len(sys.argv) >= 5 and sys.argv[1] == "split":
		split(sys.argv[2], sys.argv[3], sys.argv[4])
	else:
		sys.exit(__doc__)
