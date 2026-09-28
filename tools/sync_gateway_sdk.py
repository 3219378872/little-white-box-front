#!/usr/bin/env python3
"""Generate Gateway Dart DTOs and API methods from the reviewed OpenAPI file.

Only api/gateway.dart and data/gateway.dart are generated. Authentication,
lossless JSON, SSE and multipart streaming remain application-owned transports.
"""
from __future__ import annotations
import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
import yaml

BACKEND_API_RELATIVE_PATH=Path('little-white-box-content-community/app/gateway/openapi.yaml')
GENERATED_FILES=['api/gateway.dart','data/gateway.dart']
HEADER='// Generated from app/gateway/openapi.yaml. DO NOT EDIT.\n\n'
PRIMITIVES={'String','Object','num','int','double','bool'}

def default_backend_api_path(repo: Path) -> Path:
    for parent in repo.parents:
        candidate=parent/BACKEND_API_RELATIVE_PATH
        if candidate.is_file(): return candidate
    return repo.parent/BACKEND_API_RELATIVE_PATH

def decode(kind: str, value: str) -> str:
    if kind.endswith('?'): return f'{value} == null ? null : {decode(kind[:-1],value)}'
    if kind=='String': return f'{value}?.toString() ?? ""'
    if kind in ('Object','num'): return f'{value} ?? 0'
    if kind=='int': return f'({value} is num) ? ({value} as num).toInt() : 0'
    if kind=='double': return f'({value} is num) ? ({value} as num).toDouble() : 0.0'
    if kind=='bool': return f'{value} ?? false'
    if kind.startswith('List<'):
        item=kind[5:-1]
        if item in PRIMITIVES: return f'List<{item}>.from({value} as List? ?? const [])'
        return f'(({value} ?? []) as List).map((i) => {item}.fromJson(Map<String,dynamic>.from(i as Map))).toList()'
    if kind.startswith('Map<'): return f'{kind}.from({value} as Map? ?? const {{}})'
    return f'{kind}.fromJson(Map<String,dynamic>.from({value} as Map? ?? const {{}}))'

def encode(kind: str, field: str) -> str:
    base=kind.removesuffix('?');access=field+('?' if kind.endswith('?') else '')
    if base.startswith('List<'):
        if base[5:-1] not in PRIMITIVES: return f'{access}.map((i) => i.toJson()).toList()'
    elif base not in PRIMITIVES and not base.startswith('Map<'): return f'{access}.toJson()'
    return field

def render_types(spec: dict) -> str:
    out=[HEADER]
    for name,schema in sorted(spec['components']['schemas'].items()):
        if name=='PublicError': continue
        fields=schema.get('properties',{})
        out.append(f'class {name} {{\n')
        for prop in fields.values(): out.append(f'final {prop["x-dart-type"]} {prop["x-dart-name"]};\n')
        if fields:
            out.append(f'{name}({{\n')
            for prop in fields.values():
                required='required ' if prop['x-dart-required'] else ''
                default=' = '+prop['x-dart-default'] if 'x-dart-default' in prop else ''
                out.append(f'{required}this.{prop["x-dart-name"]}{default},\n')
            out.append('});\n')
        else: out.append(f'{name}();\n')
        out.append(f'factory {name}.fromJson(Map<String,dynamic> m) => {name}(\n')
        for key,prop in fields.items(): out.append(f'{prop["x-dart-name"]}: '+decode(prop['x-dart-type'],f"m['{key}']")+',\n')
        out.append(');\nMap<String,dynamic> toJson() => {\n')
        for key,prop in fields.items():
            field=prop['x-dart-name'];guard=f'if ({field} != null) ' if prop.get('x-dart-omit-null') else ''
            out.append(f"{guard}'{key}': {encode(prop['x-dart-type'],field)},\n")
        out.append('};\n}\n\n')
    return ''.join(out)

def render_api(spec: dict) -> str:
    out=[HEADER,"import 'api.dart';\nimport '../data/gateway.dart';\n\n"]
    for path,item in spec['paths'].items():
        for verb,operation in item.items():
            name=operation['operationId'];name=name[0].lower()+name[1:]
            req=operation.get('x-request-type');response=operation['x-response-type']
            params=operation.get('parameters',[]);paths=[p for p in params if p['in']=='path'];query=[p for p in params if p['in']=='query']
            fields=spec['components']['schemas'].get(req,{}).get('properties',{})
            # Multipart and SSE are consumed through application-owned transports.
            # Generate their route from the same source; never send them as JSON.
            if operation.get('x-sse') or 'multipart/form-data' in operation.get('requestBody',{}).get('content',{}):
                if paths:
                    arguments=','.join('Object '+p['name'] for p in paths)
                    route=re.sub(r'\{(\w+)\}',lambda m:'${Uri.encodeComponent('+m[1]+'.toString())}',path)
                    out.append(f'String {name}Path({arguments}) => "{route}";\n\n')
                else:
                    out.append(f'const {name}Path = "{path}";\n\n')
                continue
            body=verb!='get' and bool(fields)
            out.append(f'Future {name}(')
            for p in paths: out.append(f'{fields[p["name"]]["x-dart-type"].removesuffix("?")} {p["name"]},')
            if body: out.append(f'{req} request,')
            out.append('{\n')
            if verb=='get' and query: out.append(f'{req}? request,\n')
            out.append(f'Function({response})? ok,Function(String)? fail,Function? eventually,\n}}) async {{\n')
            url=re.sub(r'\{(\w+)\}',lambda m:'${Uri.encodeComponent('+m[1]+'.toString())}',path)
            out.append(f'{"var" if query and verb=="get" else "final"} url = "{url}";\n')
            if verb=='get' and query:
                names=','.join("'"+p['name']+"'" for p in query)
                out.append(f'if(request != null){{final allowed=<String>{{{names}}};final query=request.toJson()..removeWhere((k,v)=> !allowed.contains(k)||v==null);url=Uri.parse(url).replace(queryParameters:query.map((k,v)=>MapEntry(k,v.toString()))).toString();}}\n')
            args='url,'+('request,' if body else 'const {},') if verb!='get' else 'url,'
            out.append(f'await api{verb.title()}({args}ok:(data){{if(ok!=null)ok({response}.fromJson(Map<String,dynamic>.from(data as Map? ?? const {{}})));}},fail:fail,eventually:eventually);\n}}\n\n')
    return ''.join(out)

def generate(api: Path, destination: Path) -> None:
    spec=yaml.safe_load(api.read_text())
    if spec.get('openapi')!='3.0.3': raise ValueError('Gateway SDK requires OpenAPI 3.0.3')
    for rel,source in zip(GENERATED_FILES,(render_api(spec),render_types(spec))):
        path=destination/rel;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(source)
    subprocess.run(['dart','format',*(str(destination/rel) for rel in GENERATED_FILES)],check=True)

def copy_generated(src_root: Path,dest_root: Path,files: list[str]) -> None:
    for rel in files:
        destination=dest_root/rel;destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src_root/rel,destination)

def generated_differences(src_root: Path,destinations: list[Path],files: list[str]) -> list[Path]:
    return [dest/rel for dest in destinations for rel in files if not (dest/rel).is_file() or (dest/rel).read_bytes()!=(src_root/rel).read_bytes()]

def main() -> int:
    repo=Path(__file__).resolve().parents[1]
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--api');parser.add_argument('--check',action='store_true');args=parser.parse_args()
    if args.check and not args.api: parser.error('--check requires an explicit --api path to the reviewed backend revision')
    api=Path(args.api).resolve() if args.api else default_backend_api_path(repo)
    if not api.is_file(): print(f'OpenAPI contract not found: {api}',file=sys.stderr);return 1
    destinations=[repo/'vendor/sdk_source',repo/'lib/sdk']
    with tempfile.TemporaryDirectory(prefix='xbh-openapi-dart-') as temp:
        generated=Path(temp);generate(api,generated)
        if args.check:
            differences=generated_differences(generated,destinations,GENERATED_FILES)
            if differences:
                print('generated SDK drift detected:',file=sys.stderr)
                for p in differences: print(p.relative_to(repo),file=sys.stderr)
                return 1
            print('generated SDK is current')
        else:
            for dest in destinations: copy_generated(generated,dest,GENERATED_FILES)
    return 0
if __name__=='__main__': raise SystemExit(main())
