#!/usr/bin/env python3
"""Checagem estatica simples de arquivos Dart: balanceamento e imports."""
import os, re, sys
PAIRS={')':'(',']':'[','}':'{'}
def scan(src, path):
    i=0; n=len(src); stack=[]; line=1
    def err(msg): print(f"ERRO {path}:{line}: {msg}"); return False
    def string(i, quote, raw, triple):
        nonlocal line
        q=quote*3 if triple else quote
        while i<n:
            if src.startswith(q,i): return i+len(q)
            c=src[i]
            if c=="\n":
                line+=1
                if not triple: raise ValueError("string nao terminada")
            if c=="\\" and not raw: i+=2; continue
            if c=="$" and not raw:
                if i+1<n and src[i+1]=="{":
                    i=expr(i+2,1); continue
                i+=1; continue
            i+=1
        raise ValueError("string aberta")
    def expr(i, depth):
        nonlocal line
        while i<n:
            c=src[i]
            if c=="\n": line+=1
            if c=="{": depth+=1
            elif c=="}":
                depth-=1
                if depth==0: return i+1
            elif c in "'\"":
                i=lit(i); continue
            i+=1
        raise ValueError("interpolacao aberta")
    def lit(i, raw=False):
        c=src[i]
        if src.startswith(c*3,i): return string(i+3,c,raw,True)
        return string(i+1,c,raw,False)
    try:
        while i<n:
            c=src[i]
            if c=="\n": line+=1; i+=1; continue
            if src.startswith("//",i):
                j=src.find("\n",i); i=n if j<0 else j; continue
            if src.startswith("/*",i):
                j=src.find("*/",i); 
                if j<0: return err("comentario aberto")
                line+=src[i:j].count("\n"); i=j+2; continue
            if c=="r" and i+1<n and src[i+1] in "'\"" and (i==0 or not (src[i-1].isalnum() or src[i-1]=="_")):
                i=lit(i+1,raw=True); continue
            if c in "'\"": i=lit(i); continue
            if c in "([{": stack.append((c,line))
            elif c in ")]}":
                if not stack or stack[-1][0]!=PAIRS[c]: return err(f"'{c}' sem par (pilha={stack[-1] if stack else None})")
                stack.pop()
            i+=1
    except ValueError as e: return err(str(e))
    if stack: return err(f"abertos nao fechados: {stack[-3:]}")
    return True
ok=True; files=[]
for r,_,fs in os.walk("lib"):
    for f in fs:
        if f.endswith(".dart"): files.append(os.path.join(r,f))
for p in sorted(files):
    src=open(p,encoding="utf-8").read()
    if not scan(src,p): ok=False
    for m in re.finditer(r"^import '([^']+)';",src,re.M):
        imp=m.group(1)
        if imp.startswith(("package:flutter","package:shared_preferences","dart:")): continue
        t=os.path.normpath(os.path.join(os.path.dirname(p),imp))
        if not os.path.exists(t): print("ERRO import inexistente:",p,imp); ok=False
print("arquivos:",len(files),"| OK" if ok else "| FALHOU")
sys.exit(0 if ok else 1)
