#!/usr/bin/env python3
"""Build evidence-based quest -> dialogue -> NPC/map linkage for Mobile 1.1.2.3."""
from __future__ import annotations
import argparse, hashlib, json, re, struct
from collections import Counter, defaultdict
from pathlib import Path

SEED=9527

def read_text(p):
    b=p.read_bytes()
    for enc in ("utf-8-sig","utf-8","gb18030","cp1252","latin-1"):
        try:return b.decode(enc)
        except UnicodeDecodeError:pass
    return b.decode("utf-8",errors="replace")

def sections(text):
    out=[]; cur=None
    for line_no,raw in enumerate(text.splitlines(),1):
        s=raw.strip()
        if not s or s.startswith((";","#","//")):continue
        if s.startswith("[") and "]" in s:
            cur={"section":s[1:s.index("]")].strip(),"line":line_no,"fields":{}}
            out.append(cur)
        elif cur is not None and "=" in s:
            k,v=s.split("=",1);cur["fields"][k.strip()]=v.strip()
    return out

def tq_decode(data):
    state=SEED; key=bytearray()
    for _ in range(128):
        state=(state*0x343FD+0x269EC3)&0xffffffff
        key.append(((state>>16)&0x7fff)&0xff)
    out=bytearray(len(data))
    for i,b in enumerate(data):
        v=b^key[i&127]; sh=i&7
        out[i]=v if sh==0 else ((v>>sh)|(v<<(8-sh)))&255
    return bytes(out)

def parse_loc(raw):
    p=[x.strip() for x in (raw or "").split(",")]
    if p==["0"] or not raw:return {"status":"NO_REFERENCE","raw":raw}
    if len(p) not in (5,6):return {"status":"UNPARSED","raw":raw,"parts":p}
    if len(p)==6:npcid,mapid,x,y,name,mapname=p
    else:npcid,mapid,x,y,mapname=p;name=""
    try:xv=int(x);yv=int(y)
    except ValueError:xv=yv=None
    return {"status":"LOCATION_ONLY" if npcid in ("-1","0","0000") else "NPC_REFERENCE",
            "npc_id":None if npcid in ("-1","0","0000") else npcid.zfill(4),
            "raw_npc_id":npcid,"map_id":mapid,"x":xv,"y":yv,
            "name":name,"map_name":mapname,"raw":raw}

def lua_string_dict(text, prefix):
    out={}
    pat=re.compile(re.escape(prefix)+r'\["([^"]+)"\]\s*=\s*("(?:\\.|[^"\\])*")')
    for k,v in pat.findall(text):
        try: out[k]=json.loads(v)
        except Exception: out[k]=v[1:-1]
    return out

def parse_dialogues(text, npc_types, ar_text):
    starts=list(re.finditer(r'Dialog_Dialogue\[(\d+)\]\s*=\s*\{\}',text))
    blocks=[]
    for i,m in enumerate(starts):
        end=starts[i+1].start() if i+1<len(starts) else len(text)
        body=text[m.end():end]; did=int(m.group(1))
        types=[int(x) for x in re.findall(r'\["DlgType"\]\s*=\s*(\d+)',body)]
        model_ids=sorted(set(re.findall(r'\["id"\]\s*=\s*(\d+)',body)))
        text_keys=sorted(set(re.findall(r'"(STR_[A-Za-z0-9_]+)"',body)))
        funcs=sorted(set(re.findall(r'\["func"\]\s*=\s*"([^"]+)"',body)))
        funcdata=sorted(set(re.findall(r'\["funcData"\]\s*=\s*(\d+)',body)))
        names=[]
        for mid in model_ids:
            n=npc_types.get("NpcType"+mid)
            names.append({"npc_type_id":mid,"name":n})
        blocks.append({
            "dialogue_id":did,"dialogue_types":types,
            "model_references":names,"text_keys":text_keys,
            "arabic_texts":{k:ar_text[k] for k in text_keys if k in ar_text},
            "function_names":funcs,"function_data":funcdata,
        })
    return blocks

def parse_gamemap(path):
    if not path.is_file():return []
    b=path.read_bytes()
    if len(b)<4:return []
    count=struct.unpack_from("<I",b,0)[0];pos=4;out=[]
    try:
        for _ in range(count):
            mid,n=struct.unpack_from("<II",b,pos);pos+=8
            if n>4096 or pos+n+4>len(b):return []
            name=b[pos:pos+n].decode("utf-8",errors="replace");pos+=n
            flags=struct.unpack_from("<I",b,pos)[0];pos+=4
            out.append({"map_id":str(mid),"resource_path":name,"flags":flags})
        if pos!=len(b):return []
    except struct.error:return []
    return out

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("source_dir",type=Path)
    ap.add_argument("--output",type=Path,required=True)
    args=ap.parse_args();root=args.source_dir
    qpath=root/"ini/questinfo.ini"
    qsections=sections(read_text(qpath))
    quests=[s for s in qsections if s["section"].isdigit()]
    mission_ids={s["fields"].get("MissionId","") for s in quests}
    mission_ids.discard("")
    locales={}
    for locale,rel in [("ar","ini_ar/questinfo.ini"),("sp","ini_sp/questinfo.ini")]:
        p=root/rel
        if p.is_file():
            locales[locale]={s["fields"].get("MissionId","") for s in sections(read_text(p)) if s["section"].isdigit()}
    all_ids=mission_ids|set().union(*locales.values()) if locales else mission_ids
    ar_mission_names={}
    ar_path=root/"ini_ar/questinfo.ini"
    if ar_path.is_file():
        ar_mission_names={s["fields"].get("MissionId",""):s["fields"].get("Name","") for s in sections(read_text(ar_path)) if s["section"].isdigit()}

    npc_type_path=root/"ini/npc.ini"
    npc_types={}
    if npc_type_path.is_file():
        for s in sections(read_text(npc_type_path)):
            npc_types[s["section"]]=s["fields"].get("Name","")
    npcx_path=root/"ini/npcx.ini"
    npcx_names=defaultdict(list)
    if npcx_path.is_file():
        for s in sections(read_text(npcx_path)):
            if s["fields"].get("Name"):npcx_names[s["fields"]["Name"].casefold()].append(s["section"])

    mapdest_path=root/"ini/mapdestination.ini"
    mapdest=defaultdict(list); mapdest_ids=set()
    if mapdest_path.is_file():
        for s in sections(read_text(mapdest_path)):
            f=s["fields"]; mid=f.get("mapid",s["section"].split("-",1)[0])
            if mid.isdigit():mapdest_ids.add(mid)
            if f.get("npcid"):
                try:x=int(f.get("posx",""));y=int(f.get("posy",""))
                except ValueError:x=y=None
                mapdest[(mid,f["npcid"].zfill(4))].append({"section":s["section"],"title":f.get("title",""),"x":x,"y":y,"radius":f.get("radius","")})

    map_names_by_id=defaultdict(set)
    npc_refs=[]; map_refs=[]; mob_refs=[]; item_refs=[]; prereq_refs=[]; quest_condition_refs=[]; lua_refs=[]
    for s in quests:
        f=s["fields"];mid=f.get("MissionId","")
        map_field=f.get("Map","0")
        if map_field and map_field!="0":map_refs.append({"mission_id":mid,"role":"MapField","map_id":map_field,"x":None,"y":None})
        for role,key in [("begin","BeginNpcId"),("finish","FinishNpcId")]:
            loc=parse_loc(f.get(key,""))
            if loc.get("map_id") and loc.get("map_name"):map_names_by_id[loc["map_id"]].add(loc["map_name"])
            if loc["status"] in ("NPC_REFERENCE","LOCATION_ONLY"):
                map_refs.append({"mission_id":mid,"role":role,**{k:loc.get(k) for k in ("map_id","x","y")}})
            if loc["status"]=="NPC_REFERENCE":
                matches=mapdest.get((loc["map_id"],loc["npc_id"]),[])
                exact=[m for m in matches if m["x"]==loc["x"] and m["y"]==loc["y"]]
                npc_refs.append({"mission_id":mid,"role":role,**loc,
                    "npc_type_name_matches":[k for k,v in npc_types.items() if v.casefold()==loc.get("name","").casefold()],
                    "npcx_name_matches":npcx_names.get(loc.get("name","").casefold(),[]),
                    "map_destination_matches":matches,"map_destination_exact_match":bool(exact)})
            elif loc["status"]=="LOCATION_ONLY":
                npc_refs.append({"mission_id":mid,"role":role,**loc,"npc_type_name_matches":npcx_names.get(loc.get("name","").casefold(),[])})
        for key,val in f.items():
            if re.fullmatch(r"Intention\d+",key):
                for token in re.findall(r"\[([^\]]+)\]",val):
                    head,_,payload=token.partition(" ");p=[x.strip() for x in payload.split(",")] if payload else []
                    if head=="npc" and len(p)>=5:
                        raw_npc_id=p[1].strip()
                        npc_id=raw_npc_id.zfill(4) if raw_npc_id not in ("-1","0","0000") else None
                        loc={"npc_id":npc_id,"map_id":p[2],"x":int(p[3]) if p[3].isdigit() else None,"y":int(p[4]) if p[4].isdigit() else None,"name":p[0]}
                        matches=mapdest.get((loc["map_id"],loc["npc_id"]),[]) if npc_id else []
                        exact=[m for m in matches if m["x"]==loc["x"] and m["y"]==loc["y"]]
                        npc_refs.append({"mission_id":mid,"role":key,"status":"NPC_REFERENCE" if npc_id else "LOCATION_ONLY",**loc,
                            "npc_type_name_matches":[k for k,v in npc_types.items() if v.casefold()==p[0].casefold()] if npc_id else [],
                            "npcx_name_matches":npcx_names.get(p[0].casefold(),[]) if npc_id else [],
                            "map_destination_matches":matches,"map_destination_exact_match":bool(exact)})
                        map_refs.append({"mission_id":mid,"role":key,"map_id":loc["map_id"],"x":loc["x"],"y":loc["y"]})
                    elif head=="mob" and len(p)>=4:
                        mob_refs.append({"mission_id":mid,"name":p[0],"map_id":p[1],"x":int(p[2]) if p[2].isdigit() else None,"y":int(p[3]) if p[3].isdigit() else None})
                        map_refs.append({"mission_id":mid,"role":key,"map_id":p[1],"x":int(p[2]) if p[2].isdigit() else None,"y":int(p[3]) if p[3].isdigit() else None})
                    elif head=="item_t" and len(p)>=4:
                        item_refs.append({"mission_id":mid,"kind":"world_item","name":p[0],"map_id":p[1],"x":int(p[2]) if p[2].isdigit() else None,"y":int(p[3]) if p[3].isdigit() else None})
                        map_refs.append({"mission_id":mid,"role":key,"map_id":p[1],"x":int(p[2]) if p[2].isdigit() else None,"y":int(p[3]) if p[3].isdigit() else None})
                    elif head=="map" and len(p)>=4:
                        map_refs.append({"mission_id":mid,"role":key,"map_id":p[1],"x":int(p[2]) if p[2].isdigit() else None,"y":int(p[3]) if p[3].isdigit() else None})
                    elif head=="lua" and p:
                        raw_handler=p[1] if len(p)>1 else ""
                        marker_match=re.match(r"^</([A-Z]+)>",raw_handler)
                        if marker_match:
                            handler_marker=marker_match.group(1);rest=raw_handler[marker_match.end():]
                            function_name=rest.split("</",1)[0]
                            handler_data="|".join(k+":"+v for k,v in re.findall(r"</([A-Z]+)>([^<]*)",rest))
                        else:
                            trailing=re.search(r"</([A-Z]+)>(.*)$",raw_handler)
                            handler_marker=trailing.group(1) if trailing else ""
                            function_name=raw_handler[:trailing.start()] if trailing else raw_handler
                            handler_data=(trailing.group(1)+":"+trailing.group(2)) if trailing else ""
                        lua_refs.append({"mission_id":mid,"field":key,"npc_name":p[0],"script_function":function_name,"handler_marker":handler_marker,"handler_data":handler_data,"raw":token})
                    elif head=="chk_item" and len(p)>=2:item_refs.append({"mission_id":mid,"item_id":p[0],"quantity":p[1]})
                    elif head=="chk_quest" and p:quest_condition_refs.append({"mission_id":mid,"condition_quest_id":p[0],"condition_args":p[1:]})
        for p in f.get("Prequest","").split("|"):
            if p and p not in ("0","-1"):prereq_refs.append({"mission_id":mid,"required_mission_id":p})

    gamemap=parse_gamemap(root/"ini/gamemap.dat")
    gamemap_ids={x["map_id"] for x in gamemap}
    gmex_path=root/"ini/gamemapex.ini"
    gmex={s["section"]:s["fields"].get("Name","") for s in sections(read_text(gmex_path)) if s["section"].isdigit()} if gmex_path.is_file() else {}
    map_ids={r["map_id"] for r in map_refs if r.get("map_id")}
    all_map_ids=gamemap_ids|set(gmex)|mapdest_ids
    map_summary={
        "unique_map_ids_referenced":len(map_ids),
        "gamemap_dat_ids":len(gamemap_ids),"gamemapex_ini_ids":len(gmex),"mapdestination_ini_ids":len(mapdest_ids),
        "referenced_ids_missing_from_gamemap_dat":sorted(map_ids-gamemap_ids),
        "referenced_ids_missing_from_all_three_map_sources":sorted(map_ids-all_map_ids),
        "map_id_names":[{"map_id":x,"gamemapex_name":gmex.get(x),"gamemap_resource":next((m["resource_path"] for m in gamemap if m["map_id"]==x),None),"quest_source_names":sorted(map_names_by_id.get(x,set())),"mapdestination_section_count":sum(1 for s in sections(read_text(mapdest_path)) if s["section"].startswith(x+"-")) if mapdest_path.is_file() else 0} for x in sorted(map_ids)],
    }

    dlg_path=root/"ini/luaui/publicfiles/otherconf/npcdialogueinfo.dat"
    text_path=root/"ini/luaui/publicfiles/wordfiles/npcdialoguetext_ar.dat"
    dialogue_blocks=[];dialogue_ids=set();ar_text={}
    if dlg_path.is_file():
        decoded=tq_decode(dlg_path.read_bytes()).decode("utf-8",errors="replace")
        if "Dialog_Dialogue" in decoded:
            if text_path.is_file():
                text_dec=tq_decode(text_path.read_bytes()).decode("utf-8",errors="replace")
                pat=re.compile(r'NpcDialogueText_AR\["([^"]+)"\]\s*=\s*("(?:\\.|[^"\\])*")')
                for k,v in pat.findall(text_dec):
                    try:ar_text[k]=json.loads(v)
                    except Exception:ar_text[k]=v[1:-1]
            dialogue_blocks=parse_dialogues(decoded,npc_types,ar_text)
            dialogue_ids={b["dialogue_id"] for b in dialogue_blocks}
    by_mission=defaultdict(list)
    for b in dialogue_blocks:
        mid=b["dialogue_id"]//10
        suffix=b["dialogue_id"]%10
        if suffix in range(1,10) and str(mid) in mission_ids:
            by_mission[str(mid)].append(b)
    mission_dialogue=[{"mission_id":mid,"mission_name":next((q["fields"].get("Name","") for q in quests if q["fields"].get("MissionId")==mid),""),
        "mission_name_ar":ar_mission_names.get(mid,""),"dialogues":by_mission[mid]} for mid in sorted(by_mission,key=lambda x:int(x))]

    script_registry=[]
    registry_path=root/"script/luascriptmgr.dat"
    if registry_path.is_file():
        registry=tq_decode(registry_path.read_bytes()).decode("utf-8",errors="replace")
        script_registry=[{"script_id":int(a),"file":b} for a,b in re.findall(r'\[(\d+)\]\s*=\s*\{\s*file\s*=\s*"([^"]+)"',registry)]
    script_function_index=defaultdict(list)
    script_source_count=0
    for script_path in sorted((root/"script").rglob("*.dat")):
        decoded_script=tq_decode(script_path.read_bytes()).decode("utf-8",errors="replace")
        if not any(mark in decoded_script for mark in ("local function","function ","SCRIPT_DIALOG_TEXT","LuaScriptMgr_")):continue
        script_source_count+=1
        rel=str(script_path.relative_to(root))
        function_names=set(re.findall(r"(?:local\s+)?function\s+([A-Za-z_][A-Za-z0-9_:]*)",decoded_script))
        for function_name in function_names:script_function_index[function_name].append(rel)
    for ref in lua_refs:
        function_name=ref.get("script_function","")
        ref["script_function_matches"]=script_function_index.get(function_name,[])
        ref["npc_type_name_matches"]=[k for k,v in npc_types.items() if v.casefold()==ref.get("npc_name","").casefold()]
        ref["npcx_name_matches"]=npcx_names.get(ref.get("npc_name","").casefold(),[])
    scene_scripts=[]
    for entry in script_registry:
        if "client_realm_task/juqing" not in entry["file"].lower():continue
        dat_rel=entry["file"].replace(".lua",".dat")
        src=root/dat_rel
        if not src.is_file():continue
        scene=tq_decode(src.read_bytes()).decode("utf-8",errors="replace")
        scene_scripts.append({
            "script_id":entry["script_id"],"file":dat_rel,
            "created":re.search(r"--Created:\s*([^\r\n]+)",scene).group(1).strip() if re.search(r"--Created:\s*([^\r\n]+)",scene) else "",
            "function_names":re.findall(r"local function\s+(\w+)",scene),
            "api_calls":sorted(set(re.findall(r"(LuaScriptMgr_\w+)\s*\(",scene))),
            "view_positions":[{"x":int(x),"y":int(y)} for x,y in re.findall(r"LuaScriptMgr_SetViewPosByCell\((\d+)\s*,\s*(\d+)\)",scene)],
            "actor_look_candidates":[{"api":api,"look_id":int(look),"x":int(x),"y":int(y)} for api,look,x,y in re.findall(r"(LuaScriptMgr_Add(?:SimplePlayer|Player|Boss))\((\d+)\s*,\s*(\d+)\s*,\s*(\d+)",scene)],
        })

    duplicate=sorted(k for k,v in Counter(q["fields"].get("MissionId","") for q in quests).items() if k and v>1)
    missing_prereqs=sorted({r["required_mission_id"] for r in prereq_refs if r["required_mission_id"] not in all_ids})
    positive_npc_refs=[r for r in npc_refs if r.get("npc_id") not in (None,"","0000","-1")]
    placement_index=defaultdict(set);placement_data={}
    for r in npc_refs:
        if r.get("status")=="NPC_REFERENCE" and r.get("npc_id") not in (None,"","0000","-1"):
            key=(r.get("npc_id"),r.get("map_id"),r.get("x"),r.get("y"),r.get("name"))
            placement_index[key].add(r.get("mission_id",""))
            placement_data[key]={"npc_id":key[0],"map_id":key[1],"x":key[2],"y":key[3],"name":key[4],
                "npc_type_name_matches":r.get("npc_type_name_matches",[]),"npcx_name_matches":r.get("npcx_name_matches",[])}
    npc_placements=[]
    for key,data in sorted(placement_data.items(),key=lambda x:(x[0][1] or "",x[0][0] or "",x[0][2] or -1,x[0][3] or -1)):
        npc_placements.append({**data,"mission_ids":sorted(x for x in placement_index[key] if x)})
    location_only_references=[r for r in npc_refs if r.get("status")=="LOCATION_ONLY"]
    exact_matches=sum(bool(r.get("map_destination_exact_match")) for r in positive_npc_refs)
    same_npc_map=sum(bool(r.get("map_destination_matches")) for r in positive_npc_refs)
    report={
        "schema_version":"1.0.0","source_version":"Conquer Online Mobile 1.1.2.3",
        "status":"SOURCE_LINKAGE_EVIDENCE_NOT_RUNTIME_APPROVED",
        "policy":"Raw source values are preserved. Dialogue ID arithmetic matches are candidate associations; mapdestination matches are independent corroboration. NPC type-name matches do not prove a unique placement.",
        "mission_catalog":{"record_count":len(quests),"unique_mission_ids":len(mission_ids),"duplicate_mission_ids":duplicate,
            "type_counts":dict(Counter(q["fields"].get("TypeId","") for q in quests)),
            "begin_npc_positive":sum(parse_loc(q["fields"].get("BeginNpcId",""))["status"]=="NPC_REFERENCE" for q in quests),
            "finish_npc_positive":sum(parse_loc(q["fields"].get("FinishNpcId",""))["status"]=="NPC_REFERENCE" for q in quests),
            "begin_location_only":sum(parse_loc(q["fields"].get("BeginNpcId",""))["status"]=="LOCATION_ONLY" for q in quests),
            "finish_location_only":sum(parse_loc(q["fields"].get("FinishNpcId",""))["status"]=="LOCATION_ONLY" for q in quests)},
        "prerequisites":{"reference_count":len(prereq_refs),"unresolved_ids_across_locales":missing_prereqs},
        "quest_condition_reference_count":len(quest_condition_refs),"quest_condition_references":quest_condition_refs,
        "npc_linkage":{"reference_count":len(npc_refs),"unique_positive_npc_ids":len({r.get("npc_id") for r in positive_npc_refs}),
        "unique_npc_placement_count":len(npc_placements),"unique_npc_placements_by_map":dict(Counter(r["map_id"] for r in npc_placements)),
            "npc_type_name_match_references":sum(bool(r.get("npc_type_name_matches")) for r in positive_npc_refs),
            "npcx_name_match_references":sum(bool(r.get("npcx_name_matches")) for r in positive_npc_refs),
            "mapdestination_same_npc_map_matches":same_npc_map,"mapdestination_exact_coordinate_matches":exact_matches,
            "mapdestination_coordinate_conflicts":same_npc_map-exact_matches},
        "map_linkage":map_summary,
        "dialogue_linkage":{"dialogue_flow_count":len(dialogue_blocks),"arabic_dialogue_text_key_count":len(ar_text),
            "mission_ids_with_dialogue_flows":len(mission_dialogue),
            "matched_dialogue_flow_count":sum(len(x["dialogues"]) for x in mission_dialogue),
            "mission_dialogue_links":mission_dialogue},
        "story_scene_linkage":{"lua_script_registry_count":len(script_registry),"client_realm_task_registry_count":sum("client_realm_task/juqing" in x["file"].lower() for x in script_registry),
            "client_realm_task_decoded_script_count":len(scene_scripts),"scripts":scene_scripts},
        "mob_reference_count":len(mob_refs),"item_requirement_reference_count":len(item_refs),"lua_script_reference_count":len(lua_refs),"lua_script_source_files_parsed":script_source_count,"lua_script_function_match_references":sum(bool(r.get("script_function_matches")) for r in lua_refs),"lua_npc_name_match_references":sum(bool(r.get("npc_type_name_matches") or r.get("npcx_name_matches")) for r in lua_refs),
        "source_hashes":[{"path":str(p.relative_to(root)),"size_bytes":p.stat().st_size,"sha256":hashlib.sha256(p.read_bytes()).hexdigest()}
            for p in [qpath,npc_type_path,npcx_path,mapdest_path,root/"ini/gamemap.dat",gmex_path,dlg_path,text_path,registry_path] if p.is_file()],
        "npc_placements":npc_placements,"location_only_references":location_only_references,"prerequisite_references":prereq_refs,"npc_references":npc_refs,"map_references":map_refs,"mob_references":mob_refs,"item_references":item_refs,"lua_script_references":lua_refs,
        "gamemap_catalog":gamemap,
    }
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"mission_catalog":report["mission_catalog"],"npc_linkage":report["npc_linkage"],
        "map_linkage":map_summary,"dialogue_linkage":{k:v for k,v in report["dialogue_linkage"].items() if k!="mission_dialogue_links"},
        "story_scene_linkage":{k:v for k,v in report["story_scene_linkage"].items() if k!="scripts"}},ensure_ascii=False))
if __name__=="__main__":main()
