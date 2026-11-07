#!/usr/bin/env python3
"""Evidence-led analysis of Mobile quest dependencies, dialogue flows and world targets."""
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
        m=re.match(r"\[([^\]]+)\]",s)
        if m:
            cur={"section":m.group(1).strip(),"line":line_no,"fields":{}}
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

def int_or_none(x):
    try:return int(str(x).strip())
    except (TypeError,ValueError):return None

def parse_lua_value(v):
    v=v.strip()
    if v in ("DIALOG_TYPE_MODEL","DIALOG_TYPE_IMG"):return v
    if v.startswith('"') and v.endswith('"'):
        try:return json.loads(v)
        except Exception:return v[1:-1]
    return int_or_none(v) if re.fullmatch(r"-?\d+",v) else v

def scc_cycles(vertices, edges):
    graph=defaultdict(list)
    for a,b in edges:
        if a in vertices and b in vertices:graph[a].append(b)
    index=0; stack=[]; on=set(); ids={}; low={}; out=[]
    def visit(v):
        nonlocal index
        ids[v]=low[v]=index; index+=1; stack.append(v); on.add(v)
        for w in graph[v]:
            if w not in ids:
                visit(w); low[v]=min(low[v],low[w])
            elif w in on:low[v]=min(low[v],ids[w])
        if low[v]==ids[v]:
            comp=[]
            while True:
                w=stack.pop();on.remove(w);comp.append(w)
                if w==v:break
            if len(comp)>1 or any(a==b==v for a,b in edges):out.append(sorted(comp,key=lambda x:int(x) if x.isdigit() else x))
    for v in sorted(vertices,key=lambda x:int(x) if x.isdigit() else x):
        if v not in ids:visit(v)
    return out

def parse_dialogue_file(path, ar_path, mission_ids, npc_type_names, npc_appearance_names):
    if not path.is_file():return {"status":"MISSING","dialogue_count":0,"mission_flows":[]}
    text=tq_decode(path.read_bytes()).decode("utf-8",errors="replace")
    ar={}
    if ar_path.is_file():
        at=tq_decode(ar_path.read_bytes()).decode("utf-8",errors="replace")
        pat=re.compile(r'NpcDialogueText_AR\["([^"]+)"\]\s*=\s*("(?:\\.|[^"\\])*")')
        for k,v in pat.findall(at):
            try:ar[k]=json.loads(v)
            except Exception:ar[k]=v[1:-1]
    starts=list(re.finditer(r'Dialog_Dialogue\[(\d+)\]\s*=\s*\{\}',text))
    flows=[]; mission_flows=defaultdict(list); dlg_type_counts=Counter(); all_text_keys=set(); missing_keys=set()
    for i,m in enumerate(starts):
        did=int(m.group(1)); end=starts[i+1].start() if i+1<len(starts) else len(text)
        body=text[m.end():end]
        prefix=text[max(0,m.start()-450):m.start()]
        comments=re.findall(r'(?m)^\s*--\s*(\d+)\s+([^\r\n]*)',prefix)
        explicit=[(a,b) for a,b in comments if a in mission_ids]
        if explicit: mid=explicit[-1][0]; link_method="preceding_source_comment"
        elif str(did//10) in mission_ids and did>=10000: mid=str(did//10); link_method="numeric_dialogue_prefix_fallback"
        else: mid=None; link_method="unlinked"
        talk_ids=sorted({int(x) for x in re.findall(r'\["DlgTalk"\]\[(\d+)\]\s*=\s*\{\}',body)})
        talks=[]
        for tid in talk_ids:
            tp=re.compile(rf'\["DlgTalk"\]\[{tid}\]\["([^"]+)"\]\s*=\s*([^\r\n]+)')
            fields={k:parse_lua_value(v) for k,v in tp.findall(body)}
            btn_ids=sorted({int(x) for x in re.findall(rf'\["DlgTalk"\]\[{tid}\]\["DlgBtn"\]\[(\d+)\]\s*=\s*\{{\}}',body)})
            buttons=[]
            for bid in btn_ids:
                bp=re.compile(rf'\["DlgTalk"\]\[{tid}\]\["DlgBtn"\]\[{bid}\]\["([^"]+)"\]\s*=\s*([^\r\n]+)')
                buttons.append({"index":bid,"fields":{k:parse_lua_value(v) for k,v in bp.findall(body)}})
            text_key=None
            tm=re.search(rf'\["DlgTalk"\]\[{tid}\]\["DlgText"\]\["text"\]\s*=\s*"([^"]+)"',body)
            if tm:text_key=tm.group(1)
            name_key=None
            nm=re.search(rf'\["DlgTalk"\]\[{tid}\]\["DlgShowInfo"\]\["name"\]\s*=\s*"([^"]+)"',body)
            if nm:name_key=nm.group(1)
            show_id=None
            sm=re.search(rf'\["DlgTalk"\]\[{tid}\]\["DlgShowInfo"\]\["id"\]\s*=\s*(\d+)',body)
            if sm:show_id=int(sm.group(1))
            keys=[x for x in (text_key,name_key) if x]
            all_text_keys.update(keys); missing_keys.update(x for x in keys if x not in ar)
            dtype=fields.get("DlgType")
            if dtype is not None:dlg_type_counts[str(dtype)]+=1
            talks.append({"index":tid,"fields":fields,"text_key":text_key,"arabic_text":ar.get(text_key),
                "show_info":{"id":show_id,"npc_type_name":npc_type_names.get(str(show_id)) if show_id is not None else None,
                "appearance_candidates":npc_appearance_names.get(npc_type_names.get(str(show_id),"").casefold(),[]) if show_id is not None else [],
                "name_key":name_key,"arabic_name":ar.get(name_key)},"buttons":buttons})
        flow={"dialogue_id":did,"mission_id":mid,"link_method":link_method,"talk_count":len(talks),"talks":talks}
        flows.append(flow)
        if mid:mission_flows[mid].append(flow)
    return {"status":"DECODED_STRUCTURED_LUA","dialogue_count":len(flows),"mission_ids_with_flows":len(mission_flows),
        "flow_count_linked_to_missions":sum(len(v) for v in mission_flows.values()),
        "text_and_name_key_count":len(all_text_keys),"arabic_keys_found":len(all_text_keys-missing_keys),
        "arabic_keys_missing":sorted(missing_keys),"dialogue_type_counts":dict(dlg_type_counts),
        "link_methods":dict(Counter(x["link_method"] for x in flows)),
        "flows":flows,"mission_flows":[{"mission_id":k,"flows":v} for k,v in sorted(mission_flows.items(),key=lambda x:int(x[0]))]}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("source_dir",type=Path); ap.add_argument("--output",type=Path,required=True)
    a=ap.parse_args(); root=a.source_dir
    q_all=sections(read_text(root/"ini/questinfo.ini"))
    q= [s for s in q_all if s["section"].isdigit()]
    task_type_section=next((s["fields"] for s in q_all if s["section"]=="TaskType"),{})
    task_type_names={task_type_section.get("TypeId"+str(i),""):task_type_section.get("TypeName"+str(i),"") for i in range(1,int(task_type_section.get("Num","0"))+1)}
    ar_names={}
    arq=root/"ini_ar/questinfo.ini"
    if arq.is_file():
        ar_names={s["fields"].get("MissionId",""):s["fields"].get("Name","") for s in sections(read_text(arq)) if s["section"].isdigit()}
    by_id=defaultdict(list); prereq=[]; checks=[]; npc_refs=[]; map_refs=[]; mob_refs=[]; item_refs=[]
    for s in q:
        f=s["fields"]; mid=f.get("MissionId","")
        if not mid:continue
        row={"mission_id":mid,"name":f.get("Name",""),"name_ar":ar_names.get(mid,""),"type_id":f.get("TypeId",""),
             "big_type_id":f.get("BigTypeId",""),"type_name":task_type_names.get(f.get("TypeId",""),""),"level_min":int_or_none(f.get("Lv_min")),"level_max":int_or_none(f.get("Lv_max")),
             "activity_type":f.get("ActivityType",""),"repeat_or_abandon":f.get("IsCanAbondon",""),
             "map_field":f.get("Map","0"),"begin_raw":f.get("BeginNpcId",""),"finish_raw":f.get("FinishNpcId","")}
        by_id[mid].append(row)
        for p in f.get("Prequest","").split("|"):
            if p and p not in ("0","-1"):prereq.append((p,mid))
        for key,val in f.items():
            if re.fullmatch(r"Intention\d+",key):
                for tok in re.findall(r"\[([^\]]+)\]",val):
                    h,_,payload=tok.partition(" ");parts=[x.strip() for x in payload.split(",")] if payload else []
                    if h=="chk_quest" and parts:checks.append({"mission_id":mid,"condition_quest_id":parts[0],"args":parts[1:],"field":key})
                    elif h=="chk_item" and len(parts)>=2:item_refs.append({"mission_id":mid,"kind":"requirement","item_id":parts[0],"quantity":int_or_none(parts[1])})
                    elif h=="npc" and len(parts)>=5:
                        npc_refs.append({"mission_id":mid,"role":key,"name":parts[0],"npc_id":parts[1],"map_id":parts[2],"x":int_or_none(parts[3]),"y":int_or_none(parts[4]),"source":"intention"})
                        map_refs.append({"mission_id":mid,"role":key,"map_id":parts[2],"x":int_or_none(parts[3]),"y":int_or_none(parts[4])})
                    elif h=="mob" and len(parts)>=4:
                        mob_refs.append({"mission_id":mid,"name":parts[0],"map_id":parts[1],"x":int_or_none(parts[2]),"y":int_or_none(parts[3])})
                        map_refs.append({"mission_id":mid,"role":key,"map_id":parts[1],"x":int_or_none(parts[2]),"y":int_or_none(parts[3])})
                    elif h=="item_t" and len(parts)>=4:
                        item_refs.append({"mission_id":mid,"name":parts[0],"map_id":parts[1],"x":int_or_none(parts[2]),"y":int_or_none(parts[3])})
                        map_refs.append({"mission_id":mid,"role":key,"map_id":parts[1],"x":int_or_none(parts[2]),"y":int_or_none(parts[3])})
        for role,key in [("begin","BeginNpcId"),("finish","FinishNpcId")]:
            p=[x.strip() for x in f.get(key,"").split(",")]
            if len(p) in (5,6):
                if len(p)==6:nid,mp,x,y,nm,mn=p
                else:nid,mp,x,y,mn=p;nm=""
                npc_refs.append({"mission_id":mid,"role":role,"name":nm,"npc_id":nid,"map_id":mp,"x":int_or_none(x),"y":int_or_none(y),"map_name":mn,"source":"quest_endpoint"})
                map_refs.append({"mission_id":mid,"role":role,"map_id":mp,"x":int_or_none(x),"y":int_or_none(y)})
        if f.get("Map","0") not in ("","0"):
            map_refs.append({"mission_id":mid,"role":"MapField","map_id":f["Map"],"x":None,"y":None})
        prize=f.get("Prize","")
        for item_id,payload in re.findall(r"\[item\s+(\d+)\s*,\s*([^\]]*)\]",prize,re.I):
            item_refs.append({"mission_id":mid,"kind":"reward","item_id":item_id,"payload":payload})
    mission_ids=set(by_id)
    passion_path=root/"ini/questinfopassionserver.ini"
    passion_sections=sections(read_text(passion_path)) if passion_path.is_file() else []
    passion_task_type=next((s["fields"] for s in passion_sections if s["section"]=="TaskType"),{})
    passion_records=[s for s in passion_sections if s["section"].isdigit()]
    passion_ids={s["fields"].get("MissionId","") for s in passion_records if s["fields"].get("MissionId")}
    passion_type_names={passion_task_type.get("TypeId"+str(i),""):passion_task_type.get("TypeName"+str(i),"") for i in range(1,int(passion_task_type.get("Num","0"))+1)}
    unresolved=[{"prerequisite_id":p,"mission_id":m} for p,m in prereq if p not in mission_ids]
    cycles=scc_cycles(mission_ids,prereq)
    dupes={k:len(v) for k,v in by_id.items() if len(v)>1}
    # NPC/map destination references are hard joins only when the source NPC id, map and coordinates agree.
    md={}
    mp=root/"ini/mapdestination.ini"
    if mp.is_file():
        for s in sections(read_text(mp)):
            f=s["fields"]; mapid=f.get("mapid",s["section"].split("-",1)[0]); nid=f.get("npcid","")
            if nid:md.setdefault((mapid,nid.zfill(4)),[]).append({"section":s["section"],"title":f.get("title",""),"x":int_or_none(f.get("posx")),"y":int_or_none(f.get("posy"))})
    for r in npc_refs:
        matches=md.get((r["map_id"],str(r["npc_id"]).zfill(4)),[])
        r["mapdestination_matches"]=matches
        r["mapdestination_exact_coordinate_match"]=any(x["x"]==r["x"] and x["y"]==r["y"] for x in matches)
    npc_types=sections(read_text(root/"ini/npc.ini")) if (root/"ini/npc.ini").is_file() else []
    types=defaultdict(list)
    for s in npc_types:
        n=s["fields"].get("Name","")
        if n:types[n.casefold()].append(s["section"])
    npcx=sections(read_text(root/"ini/npcx.ini")) if (root/"ini/npcx.ini").is_file() else []
    skins=defaultdict(list)
    for s in npcx:
        n=s["fields"].get("Name","")
        if n:skins[n.casefold()].append(s["section"])
    for r in npc_refs:
        r["npc_type_name_candidates"]=types.get(r["name"].casefold(),[])
        r["npc_appearance_name_candidates"]=skins.get(r["name"].casefold(),[])
    monster_ids={}
    mpath=root/"ini/monstertype.ini"
    if mpath.is_file():
        for line in read_text(mpath).splitlines():
            p=line.split("@@")
            if len(p)>=2 and p[0].strip().isdigit():monster_ids.setdefault(p[1].strip().casefold(),[]).append(p[0].strip())
    for r in mob_refs:r["monster_type_ids"]=monster_ids.get(r["name"].casefold(),[])
    map_ids=set(r["map_id"] for r in map_refs if r.get("map_id"))
    gamemap=set()
    gp=root/"ini/gamemap.dat"
    if gp.is_file():
        b=gp.read_bytes()
        try:
            count=struct.unpack_from("<I",b,0)[0]; pos=4
            for _ in range(count):
                mid,n=struct.unpack_from("<II",b,pos);pos+=8+n
                gamemap.add(str(mid));pos+=4
        except Exception:pass
    gmex={s["section"] for s in sections(read_text(root/"ini/gamemapex.ini")) if s["section"].isdigit()} if (root/"ini/gamemapex.ini").is_file() else set()
    mapdest_ids={k[0] for k in md}
    npc_type_names={s["section"].replace("NpcType",""):s["fields"].get("Name","") for s in npc_types if s["section"].startswith("NpcType")}
    npc_type_defs={s["section"].replace("NpcType",""):s["fields"] for s in npc_types if s["section"].startswith("NpcType")}
    dialogue=parse_dialogue_file(root/"ini/luaui/publicfiles/otherconf/npcdialogueinfo.dat",root/"ini/luaui/publicfiles/wordfiles/npcdialoguetext_ar.dat",mission_ids,npc_type_names,skins)
    quest_npc_by_name=defaultdict(list)
    for nr in npc_refs:
        if nr.get("name"):
            key=(nr.get("mission_id"),nr.get("role"),nr.get("npc_id"),nr.get("map_id"),nr.get("x"),nr.get("y"))
            if not any((x.get("mission_id"),x.get("role"),x.get("npc_id"),x.get("map_id"),x.get("x"),x.get("y"))==key for x in quest_npc_by_name[nr["name"].casefold()]):
                quest_npc_by_name[nr["name"].casefold()].append(nr)
    dialogue_npc_refs=[]
    mission_dialogue_npcs=defaultdict(list)
    for flow in dialogue["flows"]:
        if not flow.get("mission_id"):continue
        for talk in flow["talks"]:
            info=talk.get("show_info",{})
            if info.get("npc_type_name"):
                npc_type_id=str(info["id"])
                definition=npc_type_defs.get(npc_type_id,{})
                location_candidates=quest_npc_by_name.get(info["npc_type_name"].casefold(),[])
                ref={"mission_id":flow["mission_id"],"dialogue_id":flow["dialogue_id"],"talk_index":talk["index"],
                     "npc_type_id":npc_type_id,"npc_type_name":info["npc_type_name"],
                     "simple_object_id":definition.get("SimpleObjID"),"effect":definition.get("Effect"),
                     "standby_motion":definition.get("StandByMotion"),"arabic_display_name":info.get("arabic_name"),
                     "name_key":info.get("name_key"),"appearance_candidates":info.get("appearance_candidates",[]),
                     "quest_location_candidates":[{"mission_id":x.get("mission_id"),"role":x.get("role"),"npc_id":x.get("npc_id"),
                         "map_id":x.get("map_id"),"x":x.get("x"),"y":x.get("y"),"map_name":x.get("map_name")} for x in location_candidates]}
                dialogue_npc_refs.append(ref)
                mission_dialogue_npcs[flow["mission_id"]].append(ref)
    dialogue_npc_summary={"reference_count":len(dialogue_npc_refs),
        "unique_npc_type_ids":len({r["npc_type_id"] for r in dialogue_npc_refs}),
        "mission_ids_with_dialogue_npcs":len(mission_dialogue_npcs),
        "npc_type_name_match_refs":sum(bool(r["appearance_candidates"]) for r in dialogue_npc_refs),
        "speaker_refs_with_quest_location_candidates":sum(bool(r["quest_location_candidates"]) for r in dialogue_npc_refs),
        "unique_speaker_names_with_quest_locations":len({r["npc_type_name"] for r in dialogue_npc_refs if r["quest_location_candidates"]}),
        "unique_speaker_names_without_quest_locations":sorted({r["npc_type_name"] for r in dialogue_npc_refs if not r["quest_location_candidates"]})}
    # Item lookup is optional until the itemtype directory is included in the selected source pack.
    item_defs={}
    for ip in sorted((root/"ini/itemtype").glob("*.ini")) if (root/"ini/itemtype").exists() else []:
        for line in read_text(ip).splitlines():
            p=line.split("@@")
            if len(p)>=2 and p[0].strip().isdigit():
                item_defs[p[0].strip()]={"name":p[1].strip(),"source":ip.name,"field_count":len(p)}
    item_name_index=defaultdict(list)
    for iid,meta in item_defs.items():item_name_index[meta["name"].casefold()].append(iid)
    for r in item_refs:
        iid=r.get("item_id")
        if iid:r["item_definition"]=item_defs.get(iid)
        if r.get("name"):r["item_name_candidate_ids"]=item_name_index.get(r["name"].casefold(),[])
    # Quest type ids are kept raw: the client source in this pack does not define their semantics.
    type_counts=Counter(r["type_id"] for rows in by_id.values() for r in rows)
    checks_unresolved=[x for x in checks if x["condition_quest_id"] not in mission_ids]
    report={
      "schema_version":"1.0.0","source_version":"Conquer Online Mobile 1.1.2.3",
      "policy":"Raw source values are preserved. Prequest edges and chk_quest progress conditions are reported separately. NPC template/name matches are candidates; exact mapdestination coordinate matches are stronger placement evidence. TypeId semantics are not guessed.",
      "mission_summary":{"records":len(q),"unique_ids":len(mission_ids),"duplicate_ids":dupes,"arabic_name_coverage":sum(bool(next(iter(v))["name_ar"]) for v in by_id.values()),"type_id_counts":dict(type_counts),"type_id_names":task_type_names},
      "alternate_server_catalog":{"source":"ini/questinfopassionserver.ini","records":len(passion_records),"unique_mission_ids":len(passion_ids),"overlap_with_default_catalog":len(passion_ids&mission_ids),"type_id_names":passion_type_names},
      "dependency_graph":{"prerequisite_edges":len(prereq),"unique_edges":len(set(prereq)),"unresolved_edges":unresolved,"unique_unresolved_ids":sorted({x["prerequisite_id"] for x in unresolved},key=lambda x:int(x) if x.isdigit() else x),"unresolved_ids_also_present_in_passion_server_catalog":sorted({x["prerequisite_id"] for x in unresolved if x["prerequisite_id"] in passion_ids},key=lambda x:int(x) if x.isdigit() else x),"self_edges":[{"from":p,"to":m} for p,m in prereq if p==m],"cycles":cycles,"missions_with_prerequisites":len({m for p,m in prereq}),"root_mission_count":len(mission_ids-{m for p,m in prereq if m in mission_ids})},
      "progress_conditions":{"reference_count":len(checks),"unresolved_references":checks_unresolved,"self_references":[x for x in checks if x["condition_quest_id"]==x["mission_id"]]},
      "npc_linkage":{"reference_count":len(npc_refs),"unique_positive_npc_ids":len({r["npc_id"] for r in npc_refs if int_or_none(r["npc_id"]) and int_or_none(r["npc_id"])>0}),"mapdestination_id_map_matches":sum(bool(r["mapdestination_matches"]) for r in npc_refs),"exact_coordinate_matches":sum(r["mapdestination_exact_coordinate_match"] for r in npc_refs),"npc_type_name_candidate_refs":sum(bool(r["npc_type_name_candidates"]) for r in npc_refs),"appearance_name_candidate_refs":sum(bool(r["npc_appearance_name_candidates"]) for r in npc_refs)},
      "map_linkage":{"unique_map_ids":len(map_ids),"missing_from_all_available_map_indexes":sorted(map_ids-(gamemap|gmex|mapdest_ids)),"map_ids_in_gamemap_dat":len(gamemap),"map_ids_in_gamemapex_ini":len(gmex),"map_ids_in_mapdestination_ini":len(mapdest_ids)},
      "monster_linkage":{"reference_count":len(mob_refs),"unique_names":len({r["name"] for r in mob_refs}),"matched_references":sum(bool(r["monster_type_ids"]) for r in mob_refs),"unmatched_names":sorted({r["name"] for r in mob_refs if not r["monster_type_ids"]})},
      "item_linkage":{"reference_count":len(item_refs),"unique_item_ids":len({r.get("item_id") for r in item_refs if r.get("item_id")}),"item_definitions_available":len(item_defs),"matched_item_ids":sum(bool(r.get("item_definition")) for r in item_refs if r.get("item_id")),"unmatched_item_ids":sorted({r["item_id"] for r in item_refs if r.get("item_id") and r["item_id"] not in item_defs},key=lambda x:int(x) if x.isdigit() else x),"matched_world_item_name_references":sum(bool(r.get("item_name_candidate_ids")) for r in item_refs)},
      "dialogue":{k:v for k,v in dialogue.items() if k not in ("flows","mission_flows")},"dialogue_npc_linkage":dialogue_npc_summary,
      "missions": [rows[0] for _,rows in sorted(by_id.items(),key=lambda x:int(x[0]))],
      "npc_references":npc_refs,"dialogue_npc_references":dialogue_npc_refs,"mission_dialogue_npcs":[{"mission_id":k,"npc_references":v} for k,v in sorted(mission_dialogue_npcs.items(),key=lambda x:int(x[0]))],"map_references":map_refs,"mob_references":mob_refs,"item_references":item_refs,
      "dialogue_flows":dialogue["flows"],"mission_dialogue_flows":dialogue["mission_flows"]
    }
    # Keep a compact source fingerprint manifest with the report.
    report["source_hashes"]={}
    for rel in ["ini/questinfo.ini","ini_ar/questinfo.ini","ini/npc.ini","ini/npcx.ini","ini/mapdestination.ini","ini/monstertype.ini","ini/gamemap.dat","ini/gamemapex.ini","ini/luaui/publicfiles/otherconf/npcdialogueinfo.dat","ini/luaui/publicfiles/wordfiles/npcdialoguetext_ar.dat"]:
        p=root/rel
        if p.is_file():report["source_hashes"][rel]=hashlib.sha256(p.read_bytes()).hexdigest()
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({k:v for k,v in report.items() if k in ("mission_summary","dependency_graph","progress_conditions","npc_linkage","map_linkage","monster_linkage","item_linkage","dialogue")},ensure_ascii=False))
if __name__=="__main__":main()
