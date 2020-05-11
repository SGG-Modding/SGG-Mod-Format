# Mod Importer for SuperGiant Games' Games

import os
from collections import defaultdict
from pathlib import Path

from collections import OrderedDict
from shutil import copyfile
from datetime import datetime

import xml.etree.ElementTree as xml

can_sjson = False
try:
    import sjson
    can_sjson = True
except ModuleNotFoundError:
    print("SJSON python module not found! SJSON changes will be skipped!")
    print("Get the SJSON module at https://pypi.org/project/SJSON/")

## Global Settings

modsdir = "Mods"
modsrel = ".."
gamerel = ".."
scope = "Content"
bakdir = "Backup"
baktype = ""
modfile = "modfile.txt"
comment = ":"

modified = "MODIFIED"
modified_modrep = " by Mod Importer @ "
modified_lua = "-- "+modified+" "
modified_xml = "<!-- "+modified+" -->"
modified_sjson = "/* "+modified+" */"

default_to = {"Hades":["Scripts/RoomManager.lua"],
            "Pyre":["Scripts/Campaign.lua","Scripts/MPScripts.lua"],
            "Transistor":["Scripts/AllCampaignScripts.txt"]}
default_priority = 100

kwrd_to = ["To"]
kwrd_load = ["Load"]
kwrd_priority = ["Priority"]
kwrd_include = ["Include"]
kwrd_import = ["Import"]
kwrd_xml = ["XML"]
kwrd_sjson = ["SJSON"]

reserved_sequence = "_sequence"
reserved_append = "_append"
reserved_replace = "_replace"
reserved_delete = "_delete"

## Data Functionality

DNE = ()

def safeget(data,key):
    if isinstance(data,list):
        if isinstance(key,int):
            if key < len(data) and key >= 0:
                return data[key]
        return DNE
    if isinstance(data,OrderedDict):
        return data.get(key,DNE)
    if isinstance(data,xml.ElementTree):
        root = data.getroot()
        if root:
            return root.get(k,DNE)
    if isinstance(data,xml.Element):
        return data.get(key,DNE)
    return DNE

def clearDNE(data):
    if isinstance(data,OrderedDict):
        for k,v in data.items():
            if v is DNE:
                del data[k]
                continue
            data[k] = clearDNE(v)
    if isinstance(data,list):
        L = []
        for i,v in enumerate(data):
            if v is DNE:
                continue
            L.append(clearDNE(v))
        data = L
##    if isinstance(data,xml.ElementTree):
##        root = clearDNE(data.getroot())
##        if root:
##            data._setroot(root)
##    if isinstance(data,xml.Element):
##        for v in data.findall('*'):
##            if v.text is DNE:
##                data.remove(v)
##                continue
##            clearDNE(v)
##        data.attrib = clearDNE(data.attrib)
    return data

### LUA import statement adding

def addimport(base,path):
    with open(base,'a') as basefile:
        basefile.write("\nImport "+"\""+modsrel+"/"+path+"\"")

### XML mapping

def readxml(filename):
    try:
        return xml.parse(filename)
    except xml.ParseError:
        return DNE

def writexml(filename,content,start=None):
    if not isinstance(filename,str):
        return
    if not isinstance(content, xml.ElementTree):
        return
    content.write(filename)

    #indentation styling
    data = ""
    if start:
        data = start
    with open(filename,'r') as file:
        i = 0
        for line in file:
            nl = False
            if len(line.replace('\t','').replace(' ',''))>1:
                q=True
                p=''
                for s in line:
                    if s == '\"':
                        q = not q
                    if p == '<' and q:
                        if s == '/':
                            i-=1
                            data = data[:-1]
                        else:
                            i+=1
                        data+=p
                    if s == '>' and p == '/' and q:
                        i-=1
                    if p in (' ') or (s=='>' and p == '\"') and q:
                        data+='\n'+'\t'*(i-(s=='/'))
                    if s not in (' ','\t','<') or not q:
                        data+=s
                    p=s
    open(filename,"w").write(data)

def xmlmap(indata,mapdata):
    if mapdata is DNE:
        return indata
    if type(indata)==type(mapdata):
        if isinstance(mapdata,dict):
            for k,v in mapdata.items():
                indata[k] = xmlmap(indata.get(k),v)
            return indata
        if isinstance(mapdata,xml.ElementTree):
            root = xmlmap(indata.getroot(),mapdata.getroot())
            if root:
                indata._setroot(root)
            return indata
        elif isinstance(mapdata,xml.Element):
            mtags = dict()
            for v in mapdata:
                if not mtags.get(v.tag,False):
                    mtags[v.tag]=True
            for tag in mtags:
                mes = mapdata.findall(tag)
                ies = indata.findall(tag)
                for i,me in enumerate(mes):
                    ie = safeget(ies,i)
                    if ie is DNE:
                        indata.append(me)
                        continue
                    if me.get(reserved_delete,None) not in (None,'0','false','False'):
                        indata.remove(ie)
                        continue
                    if me.get(reserved_replace,None) not in (None,'0','false','False'):
                        ie.text = me.text
                        ie.tail = me.tail
                        ie.attrib = me.attrib
                        del ie.attrib[reserved_replace]
                        continue
                    ie.text = xmlmap(ie.text,me.text)
                    ie.tail = xmlmap(ie.tail,me.tail)
                    ie.attrib = xmlmap(ie.attrib,me.attrib)
                    xmlmap(ie,me)
            return indata
        return mapdata
    else:
        return mapdata
    return mapdata

def mergexml(infile,mapfile):
    start = ""
    with open(infile,'r') as file:
        for line in file:
            if line[:5] == "<?xml" and line[-3:] == "?>\n":                
                start = line
                break
    indata = readxml(infile)
    if mapfile:
        mapdata = readxml(mapfile)
    else:
        mapdata = DNE
    indata = xmlmap(indata,mapdata)
    writexml(infile,indata,start)

### SJSON mapping

if can_sjson:
    
    def readsjson(filename):
        try:
            return sjson.loads(open(filename).read().replace('\\','\\\\'))
        except sjson.ParseException as e:
            print(repr(e))
            return DNE

    def writesjson(filename,content):
        if not isinstance(filename,str):
            return
        if isinstance(content,OrderedDict):
            content = sjson.dumps(content)
        else:
            content = ""
        with open(filename, 'w') as f:
            s = '{\n' + content + '}'
            
            #indentation styling
            p = ''
            S = ''
            for c in s:
                if c in ("{","[") and p in ("{","["):
                    S+="\n"
                if c in ("}","]") and p in ("}","]"):
                    S+="\n"
                S += c
                if p in ("{","[") and c not in ("{","[","\n"):
                    S=S[:-1]+"\n"+S[-1]
                if c in ("}","]") and p not in ("}","]","\n"):
                    S=S[:-1]+"\n"+S[-1]
                p = c
            s = S
            s = s.replace(", ","\n")
            l = s.split('\n')
            i = 0
            L = []
            for S in l:
                for c in S:
                    if c in ("}","]"):
                        i=i-1
                L.append("  "*i+S)
                for c in S:
                    if c in ("{","["):
                        i=i+1
            s = '\n'.join(L)
            
            f.write(s)

    def sjsonmap(indata,mapdata):
        if mapdata is DNE:
            return indata
        if safeget(mapdata,reserved_sequence):
            S = []
            for k,v in mapdata.items():
                try:
                    d = int(k)-len(S)
                    if d>=0:
                        S.extend([DNE]*(d+1))
                    S[int(k)]=v
                except ValueError:
                    continue
            mapdata = S
        if type(indata)==type(mapdata):
            if safeget(mapdata,0)!=reserved_append or isinstance(mapdata,OrderedDict):
                if isinstance(mapdata,list):
                    if safeget(mapdata,0)==reserved_delete:
                        return DNE
                    if safeget(mapdata,0)==reserved_replace:
                        del mapdata[0]
                        return mapdata
                    indata.expand([DNE]*(len(mapdata)-len(indata)))
                    for k,v in enumerate(mapdata):
                        indata[k] = sjsonmap(safeget(indata,k),v)
                else:
                    if safeget(mapdata,reserved_delete):
                        return DNE
                    if safeget(mapdata,reserved_replace):
                        del mapdata[reserved_replace]
                        return mapdata
                    for k,v in mapdata.items():
                        indata[k] = sjsonmap(safeget(indata,k),v)
                return indata
            elif isinstance(mapdata,list):
                for i in range(1,len(mapdata)):
                    indata.append(mapdata[i])
                return indata
        else:
            return mapdata
        return mapdata
        
    def mergesjson(infile,mapfile):
        indata = readsjson(infile)
        if mapfile:
            mapdata = readsjson(mapfile)
        else:
            mapdata = DNE
        indata = sjsonmap(indata,mapdata)
        indata = clearDNE(indata)
        writesjson(infile,indata)

## FILE/MOD CONTROL

mode_dud = 0
mode_lua = 1
mode_xml = 2
mode_sjson = 3

class modcode():
    ep = None
    ap = None
    before = None
    after = None
    rbefore = None
    rafter = None
    
    mode = mode_dud
    def __init__(self,src,data,mode,key,index,**load):
        self.src = src
        self.data = data
        self.mode = mode
        self.key = key
        self.id = index
        self.ep = load.get("ep",default_priority)

def strup(string):
    return string[0].upper()+string[1:]

selffile = "".join(os.path.realpath(__file__).replace("\\","/").split(".")[:-1])+".py"
gamedir = os.path.join(os.path.realpath(gamerel), '').replace("\\","/")[:-1]
game = strup(gamedir.split("/")[-1])

def in_directory(file,nobackup=True):
    if not os.path.isfile(file):
        return False
    file = os.path.realpath(file).replace("\\","/")
    if file == selffile:
        return False
    if nobackup:
        if os.path.commonprefix([file, gamedir+"/"+scope+"/"+bakdir]) == gamedir+"/"+scope+"/"+bakdir:
            return False
    return os.path.commonprefix([file, gamedir+"/"+scope]) == gamedir+"/"+scope

def valid_scan(file):
    if os.path.exists(file):
        if os.path.isdir(file):
            return True
    return False

def tokenise(line):
    groups = line.strip().split("\"")
    for i,group in enumerate(groups):
        if i%2:
            groups[i] = [group]
        else:
            groups[i] = group.split(" ")
    
    tokens = []
    for group in groups:
        for x in group:
            if x != '':
                tokens.append(x)

    return tokens

## FILE/MOD LOADING

codes = defaultdict(list)

def startswith(tokens,keyword,n):
    return tokens[:len(keyword)] == keyword and len(tokens)>=len(keyword)+1

def loadcommand(reldir,tokens,to,n,mode,**load):
    for path in to:
        if in_directory(path):
            args = [tokens[i::n] for i in range(n)]
            for i in range(len(args[-1])):
                sources = [reldir+"/"+arg[i].replace("\"","").replace("\\","/") for arg in args]
                paths = []
                
                num = -1
                for source in sources:
                    if valid_scan(source):
                        tpath = []
                        for file in os.scandir(source):
                            file = file.path.replace("\\","/")
                            if in_directory(file):
                                tpath.append(file)
                        paths.append(tpath)
                        if num > len(tpath) or num < 0:
                            num = len(tpath)
                    elif in_directory(source):
                        paths.append(source)
                if paths:
                    for j in range(abs(num)):
                        sources = [x[j] if isinstance(x,list) else x for x in paths]
                        codes[path].append(modcode('\n'.join(sources),tuple(sources),mode,path,len(codes[path]),**load))

def loadmodfile(filename,echo=True):
    if in_directory(filename):
        
        try:
            file = open(filename,'r')
        except IOError:
            return
        if echo:
            print(filename)

        reldir = "/".join(filename.split("/")[:-1])
        ep = 100
        to = default_to[game]
        
        with file:
            for line in file:
                line = "".join(line.split(comment)[::2])
                tokens = tokenise(line)
                
                if len(tokens)==0:
                    continue

                elif startswith(tokens,kwrd_to,0):
                    to = [s.replace("\\","/") for s in tokens[1:]]
                    if len(to) == 0:
                        to = default_to[game]
                elif startswith(tokens,kwrd_load,0):
                    n = len(kwrd_load)+len(kwrd_priority)
                    if tokens[len(kwrd_load):n] == kwrd_priority:
                        if len(tokens)>n:
                            try:
                                ep = int(tokens[n])
                            except ValueError:
                                pass
                        else:
                            ep = default_priority
                if startswith(tokens,kwrd_include,1):
                    for s in tokens[1:]:
                        path = reldir+"/"+s.replace("\"","").replace("\\","/")
                        if valid_scan(path):
                            for file in os.scandir(path):
                                loadmodfile(file.path.replace("\\","/"),echo)
                        else:
                            loadmodfile(path,echo)

                elif startswith(tokens,kwrd_import,1):
                    loadcommand(reldir,tokens[len(kwrd_import):],to,1,mode_lua,ep=ep)
                elif startswith(tokens,kwrd_xml,1):
                    loadcommand(reldir,tokens[len(kwrd_xml):],to,1,mode_xml,ep=ep)
                elif can_sjson and startswith(tokens,kwrd_sjson,1):
                    loadcommand(reldir,tokens[len(kwrd_sjson):],to,1,mode_sjson,ep=ep)
                
def sortmods(base,mods):
    codes[base].sort(key=lambda x: x.ep)
    for i in range(len(mods)):
        mods[i].id=i

def makeedit(base,mods,echo=True):
    refresh = False
    with open(base,'r') as basefile:
        for line in basefile:
              if modified+modified_modrep in line:
                  refresh = True
                  break
    Path(bakdir+"/"+"/".join(base.split("/")[:-1])).mkdir(parents=True, exist_ok=True)
    if refresh and in_directory(bakdir+"/"+base+baktype,False):
        copyfile(bakdir+"/"+base+baktype,base)
    else:
        copyfile(base,bakdir+"/"+base+baktype)
    if echo:
        i=0
        print("\n"+base)

    try:
        for mod in mods:
            if mod.mode == mode_lua:
                addimport(base,mod.data[0])
            elif mod.mode == mode_xml:
                mergexml(base,mod.data[0])
            elif mod.mode == mode_sjson:
                mergesjson(base,mod.data[0])
            if echo:
                k = i+1
                for s in mod.src.split('\n'):
                    i+=1
                    print(" #"+str(i)+" +"*(k<i)+" "*((k>=i)+5-len(str(i)))+s)
    except Exception as e:
        copyfile(bakdir+"/"+base+baktype,base)
        raise RuntimeError("Encountered uncaught exception while implementing mod changes") from e

    modifiedstr = ""
    if mods[0].mode == mode_lua:
        modifiedstr = "\n"+modified_lua
    elif mods[0].mode == mode_xml:
        modifiedstr = "\n"+modified_xml
    elif mods[0].mode == mode_sjson:
        modifiedstr = "\n"+modified_sjson
    with open(base,'a') as basefile:
        basefile.write(modifiedstr.replace(modified,modified+modified_modrep+str(datetime.now())))

def start():
    global codes
    codes = defaultdict(list)
    
    print("Reading mod files...\n")
    for mod in os.scandir(modsdir):
        loadmodfile(mod.path.replace("\\","/")+"/"+modfile)

    print("\nModified files for "+game+" mods:")
    for base, mods in codes.items():
        sortmods(base,mods)
        makeedit(base,mods)

    bs = len(codes)
    ms = sum(map(len,codes.values()))

    print("\n"+str(bs)+" base file"+"s"*(bs!=1)+" import"+"s"*(bs==1)+" a total of "+str(ms)+" mod file"+"s"*(ms!=1)+".")

if __name__ == '__main__':
    start()
    input("Press any key to end program...")
