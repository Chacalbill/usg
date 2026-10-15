#!/usr/bin/env python3
"""Gera assets do app a partir do pacote de extração (../medultra/out)."""
import json, os, re, shutil, glob, collections
SRC="/home/claude/medultra/out"; DST="/home/claude/proj/medultra_flutter/assets"
if os.path.exists(DST): shutil.rmtree(DST)
for d in ["app","data","strings","content","images","icons"]: os.makedirs(f"{DST}/{d}",exist_ok=True)
pt=json.load(open(f"{SRC}/strings/pt-BR.json"))
idx=json.load(open(f"{SRC}/data/_index.json")); used=json.load(open(f"{SRC}/data/_usado_por.json"))
menu=json.load(open(f"{SRC}/menu.json"))

# ---------- 1. faixas de idade pediátricas (em meses) ----------
def to_months(v,u): return v/4.0 if u=="s" else (v*12.0 if u=="a" else float(v))
def ranges(name, rows):
    """devolve lista [(lo,hi)] por linha; hi exclusivo; None se não aplicável"""
    out=[]; ids=[r.get("Idade") for r in rows]
    for i,r in enumerate(rows):
        v=r.get("Idade"); lo=hi=None
        if name in ("MedidaBacoPediatrico","ComprimentoRimRosenbaum"):
            s=r["Idade"] if name=="MedidaBacoPediatrico" else r["Idade"]
            m=re.match(r"^(\d+)-(\d+)_([sma]+)$",str(s))
            if m:
                u=m.group(3); ul=u[0]; uh=u[-1]
                lo=to_months(int(m.group(1)),ul); hi=to_months(int(m.group(2)),uh)
        elif name=="MedidaFigadoLoboDireito":
            m=re.match(r"^(\d+)-(\d+)m$",str(v))
            if m: lo=float(m.group(1)); hi=float(m.group(2))+1
        elif name=="ComprimentoPancreasSiegel":
            m=re.match(r"^(\d+)-(\d+)$",str(v)); lo=float(m.group(1)); hi=float(m.group(2))
        elif name.startswith("MedidaVeiaPorta"):
            m=re.match(r"^(\d+)-(\d+)$",str(v)); lo=float(m.group(1))*12; hi=float(m.group(2))*12
        elif name=="MedidaAlcasIntestinaisPediatrico":
            m=re.match(r"^(\d+)\s*-\s*(\d+)$",str(v)); lo=float(m.group(1))*12; hi=(float(m.group(2))+1)*12
        elif name=="MedidaVBPediatrico":
            if str(v).startswith("<"): lo=0.0; hi=12.0
            else: lo=float(v)*12; hi=None
        elif isinstance(v,(int,float)) or re.match(r"^\d+$",str(v)):
            lo=float(v)*12; hi=None
        out.append([lo,hi])
    # fecha buracos de linhas de ano inteiro: hi = lo da próxima linha com lo maior
    for i,(lo,hi) in enumerate(out):
        if lo is not None and hi is None:
            nxt=[o[0] for o in out[i+1:] if o[0] is not None and o[0]>lo]
            out[i][1]=nxt[0] if nxt else lo+12
    return out
PED=[n for n in idx if not n.endswith("Fetal")]
for n in idx:
    d=json.load(open(f"{SRC}/data/{n}.json"))
    if n in PED:
        for r,(lo,hi) in zip(d["rows"],ranges(n,d["rows"])):
            r["_lo"]=lo; r["_hi"]=hi
        bad=[i for i,r in enumerate(d["rows"]) if r["_lo"] is None]
        if bad: print("AVISO faixa sem parse:",n,bad)
    json.dump(d,open(f"{DST}/data/{n}.json","w"),ensure_ascii=False,separators=(",",":"))
print("tabelas de dados:",len(idx))

# ---------- 2. especificação de tabelas ----------
def gridrows(tab):
    """linhas não vazias de uma grade: lista de [(col,key)]"""
    out=[]
    for r in tab["rows"]:
        cells=[(i,k) for i,k in enumerate(r) if k]
        if cells: out.append(cells)
    return out
def find_tabela_page(target,page_pred):
    d=json.load(open(f"{SRC}/content/{target}.json"))
    def walk(n):
        yield n
        for s in n.get("subpages",[]): yield from walk(s)
    for t in d["tabs"]:
        for n in walk(t):
            if page_pred(n): yield n
TAB={}
def cell(k=None,t=None,span=1,rows=1):
    c={"span":span}
    if rows>1: c["rows"]=rows
    if k: c["k"]=k
    if t: c["t"]=t
    return c
# fetal (regras)
for g in menu["groups"]:
    for it in g["items"]:
        if it["audience"]!="fetal": continue
        for n in find_tabela_page(it["target"],lambda n:n["page"].endswith("Tabela") and n["page"] in {p for ps in used.values() for p in ps}):
            names=[x for x,ps in used.items() if n["page"] in ps and x not in TAB]
            if not names: continue
            name=names[0]; cols=idx[name]["columns"]
            disp=[]; i=0
            while i<len(cols):
                if cols[i]=="IGSemanas" and i+1<len(cols) and cols[i+1]=="IGDias": disp.append({"f":["IGSemanas","IGDias"],"fmt":"sd"}); i+=2
                else: disp.append({"f":[cols[i]],"fmt":"auto"}); i+=1
            rows=gridrows(n["tables"][0]) if n["tables"] else []
            head=[]
            if len(rows)==1:
                keys=[k for _,k in rows[0]]
                if len(keys)!=len(disp): print("AVISO cabeçalho simples não bate:",name,len(keys),len(disp))
                head=[[cell(k) for k in keys]]
            elif len(rows)>=2:
                label0=next((k for r in rows for c,k in r if c==0),None)
                groups=[k for c,k in rows[0] if c>0]
                sub=[k for c,k in rows[1]] if len(rows)>1 else []
                nval=len(disp)-1
                if groups and nval%len(groups)==0:
                    per=nval//len(groups)
                    if len(sub)*len(groups)==nval: sub=sub*len(groups)
                    if len(sub)!=nval: print("AVISO sub-cabeçalho:",name,len(sub),nval); sub=[]
                    head=[[cell(label0,rows=2)]+[cell(gk,span=per) for gk in groups]]
                    head.append([cell(k) for k in sub] if sub else [])
                else: print("AVISO grupos:",name,groups,nval)
            TAB[name]={"cols":disp,"head":head}
for n in idx:
    if n.endswith("Fetal") and n not in TAB: print("AVISO fetal sem spec:",n)
# pediátrico (manual)
def P(f,fmt="auto"): return {"f":[f] if isinstance(f,str) else f,"fmt":fmt}
def H(*rows): return [list(r) for r in rows]
C=cell
TAB["MedidaFigadoLoboDireito"]={"cols":[P("IdadeStr"),P("Media"),P("LimiteSuperior")],"head":H([C("tabelaFigadoPediatricoL1C1"),C("tabelaFigadoPediatricoL1C2"),C("tabelaFigadoPediatricoL1C4")])}
TAB["MedidaTesticulosPediatrico"]={"cols":[P("Idade"),P("Volume"),P("DP")],"head":H([C("tabelaTesticulosPediatricoL1C1"),C("tabelaTesticulosPediatricoL1C2"),C("tabelaTesticulosPediatricoL1C3")])}
TAB["MedidaVBPediatrico"]={"cols":[P("Idade")]+[P(x) for x in ["ComprimentoM","ComprimentoV","LarguraM","LarguraV","VolumeM","VolumeV"]],
  "head":H([C("tabela1VBTBPediatricoL1C1",rows=2),C("tabela1VBTBPediatricoL1C4",span=2),C("tabela1VBTBPediatricoL1C3",span=2),C("tabela1VBTBPediatricoL1C5",span=2)],
           [C("tabela1VBTBPediatricoL2C1"),C("tabela1VBTBPediatricoL2C2")]*3)}
TAB["MedidaAlcasIntestinaisPediatrico"]={"cols":[P(x) for x in ["Idade","Jejuno","ILEO","CECO","ColonA","ColonT","ColonD"]],"head":H([C(f"tabelaAlcasPediatricoL1C{i}") for i in range(1,8)])}
TAB["MedidaTireoidePediatrico"]={"cols":[P("Idade"),P("Media"),P("LimiteSuperior")],"head":H([C(f"tabela1TireoidePediatricoL1C{i}") for i in (1,2,3)])}
TAB["MedidaOvariosPediatrico"]={"cols":[P("Idade"),P("Volume"),P("DP")],"head":H([C(f"tabelaOvariosPediatricoL1C{i}") for i in (1,2,3)])}
TAB["MedidaBacoPediatrico"]={"cols":[P("Idade","range"),P("Sexo","sex"),P("Media"),P("LimiteSuperior")],"head":H([C("tabelaBacoPediatricoRosenbergL1C1"),C("sexo"),C("tabelaBacoPediatricoRosenbergL1C3"),C("tabelaBacoPediatricoRosenbergL1C5")])}
TAB["MedidaBexigaPediatricoBVI"]={"cols":[P("Idade"),P("BVI"),P("Variacao")],"head":H([C("tabela1BexigaPediatricoL1C1"),C("tabela1BexigaPediatricoL1C2BVI"),C("tabela1BexigaPediatricoL1C3BVI")])}
TAB["MedidaBexigaPediatricoBVWI"]={"cols":[P("Idade"),P("BVWI"),P("Variacao")],"head":H([C("tabela1BexigaPediatricoL1C1"),C("tabela1BexigaPediatricoL1C2BVWI"),C("tabela1BexigaPediatricoL1C3BVWI")])}
TAB["ComprimentoPancreasSiegel"]={"cols":[P("IdadeStr","loc"),P("Cabeca"),P("Corpo"),P("Cauda")],"head":H([C("tabela1PancreasPediatricoL1C1",rows=1),C("tabela1PancreasPediatricoL1C2",span=3)],[C("tabela1PancreasPediatricoL2C1"),C("tabela1PancreasPediatricoL2C2"),C("tabela1PancreasPediatricoL2C3"),C("tabela1PancreasPediatricoL2C4")])}
TAB["ComprimentoRimRosenbaum"]={"cols":[P("IdadeStr","loc"),P("Comprimento"),P("Variacao")],"head":H([C("idadeTabela"),C("tabelaRimPediatricoRosenbaumL1C3"),C("tabelaRimPediatricoRosenbaumL1C4")])}
TAB["DiametroUteroPediatrico"]={"cols":[P("Idade")]+[P(x) for x in ["DLUM","DLUDP","DAPCM","DAPCDP","DAPCeM","DAPCeDP","DAPCDAPCeM","DAPCDAPCeDP"]],
  "head":H([C("tabelaUteroDiametroL1C1",rows=2)]+[C(f"tabelaUteroDiametroL1C{i}",span=2) for i in (2,3,4,5)],[C("tabelaUteroDiametroMedia"),C("tabelaUteroDiametroDP")]*4)}
TAB["VolumeUteroPediatrico"]={"cols":[P("Idade"),P("Media"),P("DP")],"head":H([C(f"tabelaUteroVolumeL1C{i}") for i in (1,2,3)])}
for v in ("MedidaVeiaPortaMenina","MedidaVeiaPortaMenino"):
    TAB[v]={"cols":[P("IdadeStr"),P("Media"),P("DP"),P("Percentis")],"head":H([C("idadeTabelaAnos"),C("tabelaVeiaPortaAdultoSubHeader1"),C("tabelaVeiaPortaAdultoSubHeader2"),C("tabelaVeiaPortaAdultoSubHeader3")])}
# valida: todo campo existe no dado e toda chave existe em pt-BR
for n,s in TAB.items():
    cols=idx[n]["columns"]
    for c in s["cols"]:
        for f in c["f"]:
            if f not in cols: print("AVISO campo inexistente:",n,f)
    for r in s["head"]:
        for c in r:
            if c.get("k") and c["k"] not in pt: print("AVISO chave inexistente:",n,c["k"])
missing=[n for n in idx if n not in TAB]; print("sem spec:",missing)
json.dump(TAB,open(f"{DST}/app/tabelas.json","w"),ensure_ascii=False,separators=(",",":"))
sexo=set(); d=json.load(open(f"{SRC}/data/MedidaBacoPediatrico.json")); sexo={r["Sexo"] for r in d["rows"]}; print("valores Sexo (baço):",sexo)
print("colunas com variante de idioma:",[(n,[c for c in idx[n]["columns"] if c.endswith(("En","Es"))]) for n in idx if any(c.endswith(("En","Es")) for c in idx[n]["columns"])])

# ---------- 3. índice de páginas + calculadoras ----------
page2data=collections.defaultdict(list)
for x,ps in used.items():
    for p in ps:
        if not p.startswith("Crianca"): page2data[p].append(x)
PEDCFG={
 "TireoidePediatricoPrincipal":{"sections":[{"data":["MedidaTireoidePediatrico"],"units":["anos"]}]},
 "BacoPediatricoPrincipal":{"sections":[{"data":["MedidaBacoPediatrico"],"units":["meses","anos"],"sex":True}]},
 "FigadoPediatricoPrincipal":{"sections":[{"data":["MedidaFigadoLoboDireito"],"units":["meses","anos"]}]},
 "PancreasPediatricoPrincipal":{"sections":[{"data":["ComprimentoPancreasSiegel"],"units":["dias","meses","anos"]}]},
 "RimPediatricoPrincipal":{"sections":[{"data":["ComprimentoRimRosenbaum"],"units":["semanas","meses","anos"]}]},
 "OvariosPediatricoPrincipal":{"sections":[{"data":["MedidaOvariosPediatrico"],"units":["anos"]}]},
 "UteroPediatricoPrincipal":{"sections":[{"title":"uteroDiametro","data":["DiametroUteroPediatrico"],"units":["anos"]},{"title":"uteroVolume","data":["VolumeUteroPediatrico"],"units":["anos"]}]},
 "TesticulosPediatricoPrincipal":{"sections":[{"data":["MedidaTesticulosPediatrico"],"units":["anos"]}]},
 "BexigaPediatricoPrincipal":{"sections":[{"title":"indiceVolumetrico","options":[{"label":"bexigaPediatricoBVI","data":"MedidaBexigaPediatricoBVI"},{"label":"bexigaPediatricoBVWI","data":"MedidaBexigaPediatricoBVWI"}],"units":["anos"]}]},
}
FETALCFG={}
def fetal_cfg(page,tab):
    xs=page2data[page]; ck=tab["code_keys"]; sig=[k for k in ck if k.endswith("Sigla")]
    if page=="SacoGestacionalFetalCalculadora": return {"mode":"sg","data":"MedidaSacoGestacionalFetal","field":"DMSG","sigla":"dmsg"}
    if page=="DBPFetalCalculadora": return {"mode":"dbp","sections":[{"data":"MedidaDBPFetal","field":"DBP","sigla":"dbpSigla"},{"data":"MedidaCCFetal","field":"CC","sigla":"ccSigla","formula":"hadlockCC"}]}
    if page=="VesiculaVitelinicaFetalCalculadora": return {"mode":"igsd","data":xs[0]}
    if "digiteIG" in ck: return {"mode":"ig","data":xs[0]}
    return {"mode":"measure","data":xs[0],"field":idx[xs[0]]["columns"][0],"sigla":sig[0] if sig else None}
PAGES={}
def reg(n):
    p=n["page"]
    if p.endswith("Calculadora"): kind="calc"
    elif p.endswith("Principal"): kind="ped"
    elif n.get("subpages"): kind="lista"
    elif "Tabela" in p.split("Tabela")[0]+("Tabela" if "Tabela" in p else ""): kind="tabela"
    else: kind="texto"
    e={"kind":kind,"data":page2data.get(p,[])}
    if kind=="calc": e["cfg"]=fetal_cfg(p,n)
    if kind=="ped": e["cfg"]=PEDCFG[p]
    PAGES[p]=e
    for s in n.get("subpages",[]): reg(s)
for g in menu["groups"]:
    for it in g["items"]:
        d=json.load(open(f"{SRC}/content/{it['target']}.json"))
        for t in d["tabs"]: reg(t)
json.dump(PAGES,open(f"{DST}/app/paginas.json","w"),ensure_ascii=False,separators=(",",":"))
print("páginas:",collections.Counter(v["kind"] for v in PAGES.values()))
print("sem config ped:",[p for p,v in PAGES.items() if v["kind"]=="ped" and p not in PEDCFG])
# ---------- 4. cópia do restante ----------
shutil.copy(f"{SRC}/menu.json",f"{DST}/app/menu.json")
for l in ("pt-BR","en","es"): shutil.copy(f"{SRC}/strings/{l}.json",f"{DST}/strings/{l}.json")
for f in glob.glob(f"{SRC}/content/*.json"): shutil.copy(f,f"{DST}/content/")
os.makedirs(f"{DST}/content/_app",exist_ok=True)
for f in glob.glob(f"{SRC}/content/_app/*.json"): shutil.copy(f,f"{DST}/content/_app/")
for f in glob.glob(f"{SRC}/images/*.jpg"): shutil.copy(f,f"{DST}/images/")
for f in glob.glob(f"{SRC}/icons/*.png"): shutil.copy(f,f"{DST}/icons/")
tot=sum(os.path.getsize(os.path.join(r,f)) for r,_,fs in os.walk(DST) for f in fs); print("assets MB:",round(tot/1e6,1))
