import os
from collections import defaultdict
from pathlib import Path

from collections import OrderedDict
from shutil import copyfile
from datetime import datetime

can_sjson = False
try:
    import sjson
    can_sjson = True
except ModuleNotFoundError:
    print("SJSON python module not found! SJSON imports will be skipped!")
    print("Get the SJSON module at https://pypi.org/project/SJSON/")

DNE = ()

modsdir = "Mods"
modsrel = ".."
gamerel = ".."
scope = "Content"
bakdir = "Backup"
baktype = ""
modfile = "modfile.txt"
luascope = "Content/Scripts"

modified = "MODIFIED"
modified_modrep = " by Mod Importer @ "
modified_lua = "-- "+modified+" "
modified_sjson = "/* "+modified+" */"

defaultto = {"Hades":"\"Scripts/RoomManager.lua\"",
            "Pyre":"\"Scripts/Campaign.lua\" \"Content/Scripts/MPScripts.lua\"",
            "Transistor":"\"Scripts/AllCampaignScripts.txt\""}
defaultpriority = 100

kwrd_comment = ":"
kwrd_include = "Include"
kwrd_import = "Import"
kwrd_load = "Load"
kwrd_reset = "Reset"
kwrd_sjsonrem = "SJSON Rem".split(" ")
kwrd_sjsonmap = "SJSON Map".split(" ")
kwrd_to = "To"
kwrd_priorty = "Priority"

reserved_sequence = "_sequence"
reserved_append = "_append"

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

def getdataiter(data):
    if isinstance(data,list):
        return enumerate(data)
    if isinstance(data,OrderedDict):
        return data.items()
    return DNE

def safeget(data,key):
    if isinstance(data,list):
        if isinstance(key,int):
            if key < len(data) and key >= 0:
                return data[key]
        return DNE
    if isinstance(data,OrderedDict):
        return data.get(key,DNE)
    return DNE

def sequnfold(data):
    if safeget(data,reserved_sequence):
        S = []
        for k,v in data.items():
            try:
                d = int(k)-len(S)
                if d>=0:
                    S.extend([DNE]*(d+1))
                S[int(k)]=v
            except ValueError:
                continue
        data = S
    for k,v in getdataiter(data):
        data[k]=sequnfold(v)
    return data

def sjsonrem(indata,remdata):
    if remdata is DNE:
        return indata
    if type(indata)==type(remdata):
        it = getdataiter(remdata)
        if it:     
            for k,v in it:
                if not v is DNE:
                    indata[k] = sjsonrem(safeget(indata,k),v)
        else:
            return DNE
    else:
        return DNE
    return DNE

def sjsonmap(indata,mapdata):
    if mapdata is DNE:
        return indata
    if type(indata)==type(mapdata):
        if safeget(mapdata,0)!=reserved_append or isinstance(mapdata,OrderedDict):
            if isinstance(mapdata,list):
                indata.expand([DNE]*(len(mapdata)-len(indata)))
            for k,v in getdataiter(mapdata):
                indata[k] = sjsonmap(safeget(indata,k),v)
            return indata
        elif isinstance(mapdata,list):
            for i in range(1,len(mapdata)):
                indata.append(mapdata[i])
            return indata
        return mapdata
    else:
        return mapdata
    return mapdata

def clearDNE(indata):
    if isinstance(indata,OrderedDict):
        for k,v in indata.items():
            if v is DNE:
                del indata[k]
                continue
            indata[k] = clearDNE(v)
    if isinstance(indata,list):
        L = []
        for i,v in enumerate(indata):
            if v is DNE:
                continue
            L.append(clearDNE(v))
        indata = L
    return indata
    
def mergesjson(infile,mapfile,remfile):
    indata = readsjson(infile)
    if mapfile:
        mapdata = sequnfold(readsjson(mapfile))
    else:
        mapdata = DNE
    if remfile:
        remdata = sequnfold(readsjson(remfile))
    else:
        remdata = DNE
    indata = sjsonrem(indata,remdata)
    indata = sjsonmap(indata,mapdata)
    indata = clearDNE(indata)
    writesjson(infile,indata)

mode_dud = 0
mode_lua = 1
mode_sjson_rem = 2
mode_sjson_map = 3

class modcode():
    ep = defaultpriority
    ap = None
    before = None
    after = None
    rbefore = None
    rafter = None
    mode = mode_dud
    def __init__(self,src,data,mode,key,index,ep=defaultpriority):
        self.src = src
        self.data = data
        self.mode = mode
        self.key = key
        self.id = index
        self.ep = ep

def strup(string):
    return string[0].upper()+string[1:]

selffile = "".join(os.path.realpath(__file__).replace("\\","/").split(".")[:-1])+".py"
gamedir = os.path.join(os.path.realpath(gamerel), '').replace("\\","/")[:-1]
game = strup(gamedir.split("/")[-1])

def in_directory(file):
    #https://stackoverflow.com/questions/3812849/how-to-check-whether-a-directory-is-a-sub-directory-of-another-directory
    if not os.path.isfile(file):
        return False
    file = os.path.realpath(file).replace("\\","/")
    if file == selffile:
        return False
    return os.path.commonprefix([file, gamedir+"/"+scope]) == gamedir+"/"+scope

def valid_scan(file):
    if os.path.exists(file):
        if os.path.isdir(file):
            return True
    return False

codes = defaultdict(list)

def loadmodfile(filename,echo=True):
    if in_directory(filename):
        if echo:
            print(filename)
        reldir = "/".join(filename.split("/")[:-1])
        ep = 100
        to = [defaultto[game]]
        mode = mode_dud
        try:
            file = open(filename,'r')
        except IOError:
            return
        
        with file:
            for line in file:
                line = "".join(line.split(kwrd_comment)[::2])
                tokens = line.strip().split(" ")
                
                t = []
                for x in tokens:
                    if x != '':
                        t.append(x)
                tokens = t
                del t
                
                if len(tokens)==0:
                    continue
                if tokens[0] == kwrd_include and len(tokens)>1:
                    for s in tokens[1:]:
                        path = reldir+"/"+s.replace("\"","").replace("\\","/")
                        if valid_scan(path):
                            for file in os.scandir(path):
                                loadmodfile(file.path.replace("\\","/"),echo)
                        else:
                            loadmodfile(path,echo)
                
                elif tokens[0] == kwrd_import and len(tokens)>1:
                    for S in to:
                        path = S.replace("\"","").replace("\\","/")
                        if in_directory(path):
                            for s in tokens[1:]:
                                path2 = reldir+"/"+s.replace("\"","").replace("\\","/")
                                if valid_scan(path2):
                                    for file in os.scandir(path2):
                                        path2 = file.path.replace("\\","/")
                                        if in_directory(path2):
                                            codes[path].append(modcode(path2,modsrel+"/"+path2,mode_lua,path,len(codes[path]),ep))
                                elif in_directory(path2):
                                    codes[path].append(modcode(path2,modsrel+"/"+path2,mode_lua,path,len(codes[path]),ep))
            
                elif tokens[0] == kwrd_to:
                    to = tokens[1:]
                    if len(to) == 0:
                        to = [defaultto[game]]
                
                elif tokens[:len(kwrd_sjsonrem)] == kwrd_sjsonrem and can_sjson:
                    for S in to:
                        path = S.replace("\"","").replace("\\","/")
                        if in_directory(path):
                            for s in tokens[1:]:
                                path2 = reldir+"/"+s.replace("\"","").replace("\\","/")
                                if valid_scan(path2):
                                    for file in os.scandir(path2):
                                        path2 = file.path.replace("\\","/")
                                        if in_directory(path2):
                                            codes[path].append(modcode(path2,path2,mode_sjson_rem,path,len(codes[path]),ep))
                                elif in_directory(path2):
                                    codes[path].append(modcode(path2,path2,mode_sjson_rem,path,len(codes[path]),ep))
                
                elif tokens[:len(kwrd_sjsonmap)] == kwrd_sjsonmap and can_sjson:
                    for S in to:
                        path = S.replace("\"","").replace("\\","/")
                        if in_directory(path):
                            for s in tokens[1:]:
                                path2 = reldir+"/"+s.replace("\"","").replace("\\","/")
                                if valid_scan(path2):
                                    for file in os.scandir(path2):
                                        path2 = file.path.replace("\\","/")
                                        if in_directory(path2):
                                            codes[path].append(modcode(path2,path2,mode_sjson_map,path,len(codes[path]),ep))
                                elif in_directory(path2):
                                    codes[path].append(modcode(path2,path2,mode_sjson_map,path,len(codes[path]),ep))
                
                elif tokens[0] == kwrd_load and len(tokens)>1:
                    if tokens[1] == kwrd_priorty:
                        if len(tokens)>2:
                            try:
                                ep = int(tokens[2])
                            except ValueError:
                                pass
                        else:
                            ep = defaultpriority
def sortmods(base,mods):
    codes[base].sort(key=lambda x: x.ep)
    for i in range(len(mods)):
        mods[i].id=i

def addimport(base,mod):
    with open(base,'a') as basefile:
        basefile.write("\nImport "+"\""+mod.data+"\"")

def makeedit(base,mods,echo=True):
    refresh = False
    with open(base,'r') as basefile:
        for line in basefile:
              if modified+modified_modrep in line:
                  refresh = True
                  break
    Path(bakdir+"/"+"/".join(base.split("/")[:-1])).mkdir(parents=True, exist_ok=True)
    if refresh and in_directory(bakdir+"/"+base+baktype):
        copyfile(bakdir+"/"+base+baktype,base)
    else:
        copyfile(base,bakdir+"/"+base+baktype)
    if echo:
        print("\n"+base)
    i=0
    for mod in mods:
        if mod.mode == mode_lua:
            addimport(base,mod)
        elif mod.mode == mode_sjson_rem:
            mergesjson(base,None,mod.data)
        elif mod.mode == mode_sjson_map:
            mergesjson(base,mod.data,None)
        i+=1
        if echo:
            print(" #"+str(i)+" "*(6-len(str(i)))+mod.src)

    modifiedstr = ""
    if mods[0].mode == mode_lua:
        modifiedstr = "\n"+modified_lua
    if mods[0].mode in (mode_sjson_rem,mode_sjson_map):
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
