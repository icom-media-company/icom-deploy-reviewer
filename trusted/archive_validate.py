#!/usr/bin/env python3
import pathlib,stat,sys,tarfile,zipfile
if len(sys.argv)!=3 or sys.argv[1] not in {"tar","zip"}: raise SystemExit("usage: archive_validate.py tar|zip archive")
kind,path=sys.argv[1:]; seen=set()
def check(name,regular,directory,link=False):
 p=pathlib.PurePosixPath(name); norm="/".join(x for x in p.parts if x not in {"","."}) or "."
 if p.is_absolute() or ".." in p.parts or "\\" in name or norm in seen or link or not (regular or directory): raise SystemExit(f"unsafe archive member {name}")
 seen.add(norm)
if kind=="tar":
 with tarfile.open(path,"r:gz") as f:
  for m in f.getmembers(): check(m.name,m.isfile(),m.isdir(),m.issym() or m.islnk())
else:
 with zipfile.ZipFile(path) as f:
  for m in f.infolist():
   mode=m.external_attr>>16; check(m.filename,stat.S_ISREG(mode) or mode==0,m.is_dir(),stat.S_ISLNK(mode))
