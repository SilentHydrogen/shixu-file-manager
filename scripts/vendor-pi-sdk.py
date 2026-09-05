#!/usr/bin/env python3
"""Restore pinned SDK sources using Harmony ohpm convert; no npm install or protocol forks."""
import hashlib,json,os,pathlib,subprocess,tarfile,tempfile,urllib.request
ROOT=pathlib.Path(__file__).resolve().parents[1]/'packages/pi-agent-harmony'
LOCK=json.loads((ROOT/'upstream-lock.json').read_text())
OHPM=os.environ.get('OHPM_PATH','ohpm')
REGISTRY=os.environ.get('PI_PACKAGE_REGISTRY','https://registry.npmmirror.com')
with tempfile.TemporaryDirectory(prefix='shixu-pi-vendor-') as temp:
 stage=pathlib.Path(temp)
 for package in LOCK:
  name,version=package['name'],package['version']
  subprocess.run([OHPM,'convert',name+'@'+version,'--registry',REGISTRY],cwd=stage,check=True)
  candidates=list(stage.glob('convert_*/*.har'))
  match=None
  for artifact in candidates:
   with tarfile.open(artifact) as archive:
    metadata=json.load(archive.extractfile('package/oh-package.json5'))
    if metadata['name']==name and metadata['version']==version: match=artifact;break
  if match is None: raise RuntimeError('ohpm did not produce '+name+'@'+version)
  target=ROOT/'node_modules'/name;target.mkdir(parents=True,exist_ok=True)
  with tarfile.open(match) as archive:
   for member in archive.getmembers():
    if member.name.startswith('package/'):
     member.name=member.name[8:]
     if member.name: archive.extract(member,target,filter='data')
  # ohpm converts package metadata and drops npm exports. Restore only metadata for the JS bundler.
  with urllib.request.urlopen('https://registry.npmjs.org/'+name+'/'+version,timeout=30) as response: metadata=json.load(response)
  if metadata['dist']['integrity']!=package['integrity']: raise RuntimeError('Upstream integrity changed: '+name)
  # Verify converted runtime files against the exact upstream tarball integrity.
  with urllib.request.urlopen(package['tarball'],timeout=30) as response: content=response.read()
  import base64,io
  algorithm,expected=package['integrity'].split('-',1)
  if base64.b64encode(hashlib.new(algorithm,content).digest()).decode()!=expected: raise RuntimeError('Tarball integrity mismatch: '+name)
  with tarfile.open(fileobj=io.BytesIO(content),mode='r:gz') as upstream:
   for member in upstream.getmembers():
    if member.isfile() and member.name.endswith(('.js','.mjs','.cjs')):
     installed=target/member.name.removeprefix('package/')
     if not installed.exists() or installed.read_bytes()!=upstream.extractfile(member).read():
      raise RuntimeError('Converted SDK code differs from upstream: '+member.name)
  (target/'package.json').write_text(json.dumps(metadata))
print('Pinned SDK sources restored and verified; run packages/pi-agent-harmony/build.cjs next.')
