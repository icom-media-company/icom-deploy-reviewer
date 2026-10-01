#!/usr/bin/env python3
import gzip,pathlib,stat,sys,tarfile
if len(sys.argv)!=3: raise SystemExit("usage: create_reproducible_tar.py root output.tar.gz")
root=pathlib.Path(sys.argv[1]).resolve(); output=pathlib.Path(sys.argv[2])
if not root.is_dir() or output.exists(): raise SystemExit("invalid root or existing output")
with output.open("wb") as raw, gzip.GzipFile(filename="",mode="wb",fileobj=raw,mtime=0,compresslevel=9) as gz, tarfile.open(fileobj=gz,mode="w",format=tarfile.PAX_FORMAT) as tar:
 for path in sorted(root.rglob("*"),key=lambda p:p.relative_to(root).as_posix()):
  if path.is_symlink() or not (path.is_dir() or path.is_file()): raise SystemExit(f"unsafe source: {path}")
  rel=path.relative_to(root).as_posix(); info=tar.gettarinfo(str(path),arcname=rel)
  info.uid=info.gid=0; info.uname=info.gname=""; info.mtime=0
  info.mode=0o755 if path.is_dir() or (path.parent.name=="scripts" and path.name.endswith(".sh")) else 0o644
  if path.is_file():
   with path.open("rb") as source: tar.addfile(info,source)
  else: tar.addfile(info)
