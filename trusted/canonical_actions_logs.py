#!/usr/bin/env python3
import hashlib,json,pathlib,stat,sys,zipfile

def canonical_digest(archive_path, expected_names):
 expected=sorted(expected_names); items=[]; seen=set()
 with zipfile.ZipFile(archive_path) as archive:
  for entry in archive.infolist():
   name=entry.filename; path=pathlib.PurePosixPath(name); mode=entry.external_attr>>16
   if path.is_absolute() or ".." in path.parts or "\\" in name or path.as_posix()!=name or name in seen:
    raise ValueError("unsafe/duplicate log entry")
   if entry.is_dir() or stat.S_ISLNK(mode) or (mode and not stat.S_ISREG(mode)):
    raise ValueError("non-regular log entry")
   seen.add(name); content=archive.read(entry)
   items.append({"name":name,"sha256":hashlib.sha256(content).hexdigest(),"size":len(content)})
 if sorted(seen)!=expected: raise ValueError("log entry census mismatch")
 raw=json.dumps(sorted(items,key=lambda item:item["name"]),sort_keys=True,separators=(",",":")).encode()
 return hashlib.sha256(raw).hexdigest()

if __name__=="__main__":
 if len(sys.argv)<4: raise SystemExit("usage: canonical_actions_logs.py archive expected-sha name...")
 try: digest=canonical_digest(sys.argv[1],sys.argv[3:])
 except (OSError,ValueError,zipfile.BadZipFile) as error: raise SystemExit(str(error))
 if digest!=sys.argv[2]: raise SystemExit("canonical log content digest mismatch")
 print(digest)
