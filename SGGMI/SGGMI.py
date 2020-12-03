"""
Mod Importer for SuperGiant Games' Games

https://github.com/MagicGonads/sgg-mod-format
"""

__all__ = [
    #functions
        "main", "configure_globals", "start", "preplogfile", "cleanup",
        "safeget", "safeset", "dictmap", "hashfile",
        "lua_addimport",
        "xml_safeget", "xml_read", "xml_write", "xml_map", "xml_merge",
        "sjson_safeget", "sjson_clearDNE", "sjson_read", "sjson_write",
        "sjson_map", "sjson_merge", 
    #variables
        "configfile", "logfile_prefix", "logfile_suffix", "edited_suffix",
        "scopemods", "modsrel", "baserel", "editrel", "logsrel", "gamerel",
        "do_log", "cfg_modify", "cfg_overwrite", "profile_use_special",
    #modules
        "logging","xml","sjson","yaml","hashlib",
    #other
        "DNE",
        ]
__version__ = '1.0a-r4'
__author__ = 'Andre Issa'

# Dependencies

import os, sys, stat
import logging
import warnings
import hashlib
from getopt import getopt
from pathlib import Path
from shutil import copyfile, rmtree
from datetime import datetime
from collections import defaultdict
from distutils.dir_util import copy_tree
from distutils.errors import DistutilsFileError

## Importer Config

try:
    import yaml # pip: PyYAML
except ModuleNotFoundError:
    yaml = None

## XML Handling

import xml.etree.ElementTree as xml

## SJSON Handling
try:
    import sjson  # pip: SJSON
except ModuleNotFoundError:
    sjson = None
else:
    from collections import OrderedDict

# Configurable Globals

configfile = 'miconfig.yml'
#### These are better configured using the config file to be specific to different installs
scopemods = "Deploy" # Must be accessible to game scope
modsrel = "Mods"
baserel = "Base Cache"
editrel = "Edit Cache"
logsrel = "Logs"
logfile_prefix = "log-modimp "
logfile_suffix = ".txt"
edited_suffix = ".hash"

# Data Functionality

DNE = ()  # 'Does Not Exist' singleton

def safeget(data,key,default=DNE,skipnone=True):
    if data is None:
        data = globals()
    if isinstance(data,list) or isinstance(data,tuple):
        if isinstance(key,int):
            if key < len(data) and key >= 0:
                ret = data[key]
                return default if skipnone and ret is None else ret
        return default
    if isinstance(data,dict):
            ret = data.get(key,default)
            return default if skipnone and ret is None else ret
    return default

def safeset(data,key,value):
    if data is None:
        data = globals()
    if isinstance(data,list):
        if isinstance(key,int):
            if key < len(data) and key >= 0:
                data[key]=value
    if isinstance(data,dict):
            data[key]=value

def dictmap(indict,mapdict):
    if mapdict is DNE or mapdict is indict:
        return indict
    if type(indict)==type(mapdict):
        if isinstance(mapdict,dict):
            for k,v in mapdict.items():
                indict[k] = dictmap(safeget(indict,k),v)
            return indict
    return mapdict

## LUA import statement adding

def lua_addimport(base,path):
    with open(base,'a') as basefile:
        basefile.write("\nImport \"../"+path+"\"")

## XML mapping

xml_RESERVED_replace = "_replace"
xml_RESERVED_delete = "_delete"

def xml_safeget(data,key):
    if isinstance(data,list):
        if isinstance(key,int):
            if key < len(data) and key >= 0:
                return data[key]
        return DNE
    if isinstance(data,xml.ElementTree):
        root = data.getroot()
        if root:
            return root.get(k,DNE)
    if isinstance(data,xml.Element):
        return data.get(key,DNE)
    return DNE

def xml_read(filename):
    try:
        return xml.parse(filename)
    except xml.ParseError:
        return DNE

def xml_write(filename,content,start=None):
    if not isinstance(filename,str):
        return
    if not isinstance(content, xml.ElementTree):
        return
    content.write(filename)

    # Indentation styling
    data = ""
    if start:
        data = start
    with open(filename,'r') as file:
        i = 0
        for line in file:
            nl = False
            if len(line.replace('\t','').replace(' ','')) > 1:
                q = True
                p = ''
                for s in line:
                    if s == '\"':
                        q = not q
                    if p == '<' and q:
                        if s == '/':
                            i -= 1
                            data = data[:-1]
                        else:
                            i += 1
                        data+=p
                    if s == '>' and p == '/' and q:
                        i -= 1
                    if p in (' ') or (s == '>' and p == '\"') and q:
                        data += '\n' + '\t'*(i - (s == '/'))
                    if s not in (' ','\t','<') or not q:
                        data += s
                    p=s
    open(filename,"w").write(data)

def xml_map(indata,mapdata):
    if mapdata is DNE:
        return indata
    if type(indata) == type(mapdata):
        if isinstance(mapdata,dict):
            for k,v in mapdata.items():
                indata[k] = xml_map(indata.get(k),v)
            return indata
        if isinstance(mapdata,xml.ElementTree):
            root = xml_map(indata.getroot(),mapdata.getroot())
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
                    ie = xml_safeget(ies,i)
                    if ie is DNE:
                        indata.append(me)
                        continue
                    if me.get(xml_RESERVED_delete,None) \
                            not in {None,'0','false','False'}:
                        indata.remove(ie)
                        continue
                    if me.get(xml_RESERVED_replace,None) \
                            not in {None,'0','false','False'}:
                        ie.text = me.text
                        ie.tail = me.tail
                        ie.attrib = me.attrib
                        del ie.attrib[xml_RESERVED_replace]
                        continue
                    ie.text = xml_map(ie.text,me.text)
                    ie.tail = xml_map(ie.tail,me.tail)
                    ie.attrib = xml_map(ie.attrib,me.attrib)
                    xml_map(ie,me)
            return indata
        return mapdata
    else:
        return mapdata
    return mapdata

def xml_merge(infile,mapfile):
    start = ""
    with open(infile,'r') as file:
        for line in file:
            if line[:5] == "<?xml" and line[-3:] == "?>\n":                
                start = line
                break
    indata = xml_read(infile)
    if mapfile:
        mapdata = xml_read(mapfile)
    else:
        mapdata = DNE
    indata = xml_map(indata,mapdata)
    xml_write(infile,indata,start)

## SJSON mapping

if sjson is not None:

    sjson_RESERVED_sequence = "_sequence"
    sjson_RESERVED_append = "_append"
    sjson_RESERVED_replace = "_replace"
    sjson_RESERVED_delete = "_delete"

    def sjson_safeget(data,key):
        if isinstance(data,list):
            if isinstance(key,int):
                if key < len(data) and key >= 0:
                    return data[key]
            return DNE
        if isinstance(data,OrderedDict):
            return data.get(key,DNE)
        return DNE

    def sjson_clearDNE(data):
        if isinstance(data,OrderedDict):
            for k,v in data.items():
                if v is DNE:
                    del data[k]
                    continue
                data[k] = sjson_clearDNE(v)
        if isinstance(data,list):
            L = []
            for i,v in enumerate(data):
                if v is DNE:
                    continue
                L.append(sjson_clearDNE(v))
            data = L
        return data
    
    def sjson_read(filename):
        try:
            return sjson.loads(open(filename).read().replace('\\','\\\\'))
        except sjson.ParseException as e:
            alt_print(repr(e))
            return DNE

    def sjson_write(filename,content):
        if not isinstance(filename,str):
            return
        if isinstance(content,OrderedDict):
            content = sjson.dumps(content)
        else:
            content = ""
        with open(filename, 'w') as f:
            s = '{\n' + content + '}'
            
            # Indentation styling
            p = ''
            S = ''
            for c in s:
                if c in ("{","[") and p in ("{","["):
                    S += "\n"
                if c in ("}","]") and p in ("}","]"):
                    S += "\n"
                S += c
                if p in ("{","[") and c not in ("{","[","\n"):
                    S = S[:-1] + "\n" + S[-1]
                if c in ("}","]") and p not in ("}","]","\n"):
                    S = S[:-1] + "\n" + S[-1]
                p = c
            s = S.replace(", ","\n").split('\n')
            i = 0
            L = []
            for S in s:
                for c in S:
                    if c in ("}","]"):
                        i = i - 1
                L.append("  "*i+S)
                for c in S:
                    if c in ("{","["):
                        i=i+1
            s = '\n'.join(L)
            
            f.write(s)

    def sjson_map(indata,mapdata):
        if mapdata is DNE:
            return indata
        if sjson_safeget(mapdata,sjson_RESERVED_sequence):
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
            if sjson_safeget(mapdata,0) != sjson_RESERVED_append \
                           or isinstance(mapdata,OrderedDict):
                if isinstance(mapdata,list):
                    if sjson_safeget(mapdata,0) == sjson_RESERVED_delete:
                        return DNE
                    if sjson_safeget(mapdata,0) == sjson_RESERVED_replace:
                        del mapdata[0]
                        return mapdata
                    indata.expand([DNE]*(len(mapdata) - len(indata)))
                    for k,v in enumerate(mapdata):
                        indata[k] = sjson_map(sjson_safeget(indata,k),v)
                else:
                    if sjson_safeget(mapdata,sjson_RESERVED_delete):
                        return DNE
                    if sjson_safeget(mapdata,sjson_RESERVED_replace):
                        del mapdata[sjson_RESERVED_replace]
                        return mapdata
                    for k,v in mapdata.items():
                        indata[k] = sjson_map(sjson_safeget(indata,k),v)
                return indata
            elif isinstance(mapdata,list):
                for i in range(1,len(mapdata)):
                    indata.append(mapdata[i])
                return indata
        else:
            return mapdata
        return mapdata
        
    def sjson_merge(infile,mapfile):
        indata = sjson_read(infile)
        if mapfile:
            mapdata = sjson_read(mapfile)
        else:
            mapdata = DNE
        indata = sjson_map(indata,mapdata)
        indata = sjson_clearDNE(indata)
        sjson_write(infile,indata)

else:
    
    sjson_safeget = None
    sjson_clearDNE = None
    sjson_read = None
    sjson_write = None
    sjson_map = None
    sjson_merge = None

# FILE/MOD CONTROL

class Signal():
    truth = False
    message = None
    def __init__(self,truth=False,message=None):
        self.truth = truth
        self.message = message
    def __bool__(self):
        return self.truth
    def __eq__(self,other):
        if isinstance(other,Signal):
            return (self.truth,self.message)==(other.truth,other.message)
        return False
    def __str__(self):
        return str(self.message)
    def __repr__(self):
        return self.__class__.__name__ + \
               "("+self.truth.__repr__() + ',' + self.message.__repr__() + ')'

hashes = ['md5']
def hashfile(file,out=None,modes=hashes,blocksize=65536):
    lines = []
    for mode in modes:
        hasher = hashlib.new(mode)
        with open(file, 'rb') as afile:
            buf = afile.read(blocksize)
            while len(buf) > 0:
                hasher.update(buf)
                buf = afile.read(blocksize)
            lines.append(mode+'\t'+hasher.hexdigest())
    content = "\n".join(lines)
    if out:
        with open(out, 'w') as ofile:
            ofile.write(content)
    return content

def is_subfile(filename,folder):
    if os.path.exists(filename):
        if os.path.commonprefix([filename, folder]) == folder:
            if os.path.isfile(filename):
                return Signal(True,"SubFile")
            return Signal(False,"SubDir")
        return Signal(False,"NonSub")
    return Signal(False,"DoesNotExist")

def in_scope(filename,permit_DNE=False):
    if os.path.exists(filename) or permit_DNE:
        if local_in_scope:
            tfile = filename[len(os.path.commonprefix([filename, localdir])):]
            tfile = tfile.split("/")[1]
            if tfile in localsources:
                return Signal(False,"IsLocalSource")
        if base_in_scope:
            if os.path.commonprefix([filename, basedir]) == basedir:
                return Signal(False,"InBase")
        if edit_in_scope:
            if os.path.commonprefix([filename, editdir]) == editdir:
                return Signal(False,"InEdits")
        if os.path.commonprefix([filename, scopedir]) == scopedir:
            if os.path.isfile(filename):
                return Signal(True,"FileInScope")
            return Signal(False,"DirInScope")
        return Signal(False,"OutOfScope")
    return Signal(False,"DoesNotExist")

def alt_print(*args,**kwargs):
    if do_echo:
        return print(*args,**kwargs)
    if do_log:
        tlog = logsdir+'/'+'temp-'+logfile_prefix+thetime()+logfile_suffix
        f=open(tlog,'w')
        print(file=f,*args,**kwargs)
        f.close()
        f=open(tlog,'r')
        data=f.read()
        f.close()
        os.remove(tlog)
        return logging.getLogger(__name__).info(data)

def alt_warn(message):
    warnings.warn(message,stacklevel = 2)
    if do_log and do_echo:
        logging.getLogger(__name__).warning(message)

def alt_input(*args,**kwargs):
    if do_echo:
        if do_input:
            return input(*args)
        print(*args)
        return kwargs.get('default',None)
    if do_log:
        tlog = logsdir+'/'+'temp-'+logfile_prefix+thetime()+logfile_suffix
        f=open(tlog,'w')
        print(file=f,*args)
        f.close()
        f=open(tlog,'r')
        data=f.read()
        f.close()
        os.remove(tlog)        
        logging.getLogger(__name__).info(data)
        if do_input:
            return input()
        return kwargs.get('default',None)

def alt_exit(code=None):
    alt_input("Press any key to end program...")
    exit(code)

def modfile_splitlines(body):
    glines = map(lambda s: s.strip().split("\""),body.split("\n"))
    lines = []
    li = -1
    mlcom = False
    def gp(group,lines,li,mlcom,even):
        if mlcom:
            tgroup = group.split(modfile_mlcom_end,1)
            if len(tgroup)==1: # still commented, carry on
                even = not even
                return (lines,li,mlcom,even)
            else: # comment ends, if a quote, even is disrupted
                even = False
                mlcom = False
                group = tgroup[1]
        if even:
            lines[li]+="\""+group+"\""
        else:
            tgroup = group.split(modfile_comment,1)
            tline = tgroup[0].split(modfile_mlcom_start,1)
            tgroup = tline[0].split(modfile_linebreak)
            lines[li]+=tgroup[0] # uncommented line
            for g in tgroup[1:]: # new uncommented lines
                lines.append(g)
                li+=1
            if len(tline)>1: # comment begins
                mlcom = True
                lines,li,mlcom,even = gp(tline[1],lines,li,mlcom,even)
        return (lines,li,mlcom,even)
    for groups in glines:
        even = False
        li += 1
        lines.append("")
        for group in groups:
            lines,li,mlcom,even = gp(group,lines,li,mlcom,even)
            even = not even
    return lines

def modfile_tokenise(line):
    groups = line.strip().split("\"")
    for i,group in enumerate(groups):
        if i%2:
            groups[i] = [group]
        else:
            groups[i] = group.replace(" ",modfile_delimiter)
            groups[i] = groups[i].split(modfile_delimiter)
    tokens = []
    for group in groups:
        for x in group:
            if x != '':
                tokens.append(x)
    return tokens

class Mod():
    """ modcode data structure """
    
    mode = ""
    
    def __init__(self,src,data,mode,key,index,**load):
        self.src = src
        self.data = data
        self.mode = mode
        self.key = key
        self.id = index
        self.load = {"priority":default_priority}
        self.load.update(load)


# FILE/MOD LOADING

def modfile_startswith(tokens,keyword,n):
    return tokens[:len(keyword)] == keyword and len(tokens)>=len(keyword)+1

def modfile_loadcommand(reldir,tokens,to,n,mode,cfg={},**load):
    for scopepath in to:
        path = scopedir+'/'+scopepath
        if in_scope(path):
            args = [tokens[i::n] for i in range(n)]
            for i in range(len(args[-1])):
                sources = [reldir + "/" + \
                           arg[i].replace("\"","").replace("\\","/") \
                           for arg in args]
                paths = []
                num = -1
                for source in sources:
                    if os.path.isdir(modsdir+'/'+source):
                        tpath = []
                        for file in os.scandir(source):
                            file = file.path.replace("\\","/")
                            if in_scope(file):
                                tpath.append(file)
                        paths.append(tpath)
                        if num > len(tpath) or num < 0:
                            num = len(tpath)
                    elif in_scope(modsdir+'/'+source):
                        paths.append(source)
                if paths:
                    for j in range(abs(num)):
                        sources = [x[j] if isinstance(x,list) \
                                   else x for x in paths]
                        for src in sources:
                            todeploy[src]=dictmap(todeploy.get(src,cfg),cfg)
                        f = lambda x: map(lambda y: deploy_from_scope+'/'+y,x)
                        codes[scopepath].append(Mod('\n'.join(sources),
                                               tuple(f(sources)),mode,scopepath,
                                               len(codes[scopepath]),**load))

def modfile_load(filename,echo=True):
    sig = is_subfile(filename,modsdir)
    if sig:
        prefix = os.path.commonprefix([filename,modsdir])
        relname = filename[len(prefix)+1:]
        try:
            file = open(filename,'r')
        except IOError:
            return
        if echo:
            alt_print(relname)

        reldir = "/".join(relname.split("/")[:-1])
        p = default_priority
        to = default_target
        cfg = {}
        
        with file:    
            for line in modfile_splitlines(file.read()):
                tokens = modfile_tokenise(line) 
                if len(tokens)==0:
                    continue

                elif modfile_startswith(tokens,KWRD_to,0):
                    to = [s.replace("\\","/") for s in tokens[1:]]
                    if len(to) == 0:
                        to = default_target
                elif modfile_startswith(tokens,KWRD_load,0):
                    n = len(KWRD_load)+len(KWRD_priority)
                    if tokens[len(KWRD_load):n] == KWRD_priority:
                        if len(tokens)>n:
                            try:
                                p = int(tokens[n])
                            except ValueError:
                                pass
                        else:
                            p = default_priority
                if modfile_startswith(tokens,KWRD_include,1):
                    for s in tokens[1:]:
                        modfile_load(reldir+"/"+
                                     s.replace("\"","").replace("\\","/"),echo)
                elif modfile_startswith(tokens,KWRD_deploy,1):
                    for s in tokens[1:]:
                        check = is_subfile(s,modsdir)
                        if check:
                            todeploy[s]=dictmap(todeploy.get(s,cfg),cfg)
                        elif check.message == "SubDir":
                            for f in os.scandir(s):
                                S=f.path.replace("\\","/")
                                todeploy[S]=dictmap(todeploy.get(S,cfg),cfg)
                            
                elif modfile_startswith(tokens,KWRD_import,1):
                    modfile_loadcommand(reldir,tokens[len(KWRD_import):],
                                        to,1,'lua',cfg,priority=p)
                elif modfile_startswith(tokens,KWRD_xml,1):
                    modfile_loadcommand(reldir,tokens[len(KWRD_xml):],
                                        to,1,'xml',cfg,priority=p)
                elif modfile_startswith(tokens,KWRD_sjson,1):
                    if sjson:
                        modfile_loadcommand(reldir,tokens[len(KWRD_sjson):],
                                        to,1,'sjson',cfg,priority=p)
                    else:
                        alt_warn("SJSON module not found! Skipped command: "+line)
                        
    elif sig.message == "SubDir":
        for file in os.scandir(filename):
            modfile_load(file.path.replace("\\","/"),echo)

def is_edited(base):
    if os.path.isfile(editdir+'/'+base+edited_suffix):
        efile = open(editdir+'/'+base+edited_suffix,'r')
        data = efile.read()
        efile.close()
        return data == hashfile(scopedir+'/'+base)
    return False

def deploy_mods():
    for fs,cfg in todeploy.items():
        Path(deploydir+"/"+"/".join(fs.split("/")[:-1])).mkdir(parents=True, exist_ok=True)
        copyfile(modsdir+'/'+fs,deploydir+"/"+fs)

def sort_mods(base,mods):
    codes[base].sort(key=lambda x: x.load['priority'])
    for i in range(len(mods)):
        mods[i].id=i

def make_base_edits(base,mods,echo=True):
    Path(basedir+"/"+"/".join(base.split("/")[:-1])).mkdir(parents=True, exist_ok=True)
    copyfile(scopedir+'/'+base,basedir+"/"+base)
    if echo:
        i=0
        alt_print("\n"+base)

    try:
        for mod in mods:
            if mod.mode == 'lua':
                lua_addimport(scopedir+'/'+base,mod.data[0])
            elif mod.mode == 'xml':
                xml_merge(scopedir+'/'+base,mod.data[0])
            elif mod.mode == 'sjson':
                sjson_merge(scopedir+'/'+base,mod.data[0])
            if echo:
                k = i+1
                for s in mod.src.split('\n'):
                    i+=1
                    alt_print(" #"+str(i)+" +"*(k<i)+" "*((k>=i)+5-len(str(i)))+s)
    except Exception as e:
        copyfile(basedir+"/"+base,scopedir+'/'+base)
        raise RuntimeError("Encountered uncaught exception while implementing mod changes") from e
    
    Path(editdir+"/"+"/".join(base.split("/")[:-1])).mkdir(parents=True, exist_ok=True)
    hashfile(scopedir+'/'+base,editdir+'/'+base+edited_suffix)

def cleanup(folder=None,echo=True):
    if not os.path.exists(folder):
        return True
    if os.path.isdir(folder):
        empty = True
        for content in os.scandir(folder):
            if cleanup(content,echo):
                empty = False
        if empty:
            os.rmdir(folder)
            return False
        return True
    if isinstance(folder,str):
        return None
    folderpath = folder.path.replace("\\","/")
    path = folderpath[len(basedir)+1:]
    if os.path.isfile(scopedir+'/'+path):
        if is_edited(path):
            copyfile(folderpath,scopedir+'/'+path)
        if echo:
            alt_print(path)
        os.remove(folderpath)
        return False
    return True

def restorebase(echo=True):
    if not cleanup(basedir,echo):
        try:
            copy_tree(basedir,scopedir)
        except DistutilsFileError:
            pass    

# Global Preprocessing

def thetime():
    return datetime.now().strftime("%d.%m.%Y-%I.%M%p-%S.%f")

def preplogfile():
    if do_log:
        Path(logsdir).mkdir(parents=True, exist_ok=True)
        logging.basicConfig(filename= \
                            logsdir+"/"+logfile_prefix+thetime()+logfile_suffix,
                            level = logging.INFO)
    logging.captureWarnings(do_log and not do_echo)

def update_scope(rel='..'):
    global gamedir
    gamedir = os.path.join(os.path.realpath(rel), '').replace("\\","/")[:-1]
    global scopeparent
    scopeparent = gamedir.split('/')[-1]
    global scopedir
    scopedir = gamedir+'/'+scope

def configure_globals(condict={},flow=True):

    global do_echo,do_log,do_input
    do_echo = safeget(condict,'echo',do_echo)
    do_log = safeget(condict,'log',do_log)
    do_input = safeget(condict,'input',do_input)

    global logsrel,logfile_prefix,logfile_suffix
    logsrel = safeget(condict,'log_folder',logsrel)
    logfile_prefix = safeget(condict,'log_prefix',logfile_prefix)
    logfile_suffix = safeget(condict,'log_suffix',logfile_suffix)

    global logsdir
    logsdir = os.path.join(os.path.realpath(logsrel), '').replace("\\","/")
    preplogfile()

    global hashes
    hashes = safeget(condict,'hashes',hashes)

    global  thisfile, localdir, localparent            
    thisfile = os.path.realpath(__file__).replace("\\","/")
    localdir = '/'.join(thisfile.split('/')[:-1])
    localparent = localdir.split('/')[-2]

    global profiles, profile, folderprofile
    profiles = {}
    profiles.update(safeget(condict,'profiles',{}))
    profile = None

    folderprofile = safeget(condict,'profile',localparent)
    if profile_use_special:
            profile = safeget(condict,'profile_special',profile)
    while profile is None:
        profile = safeget(profiles,folderprofile,None)
        if profile is None:
            if not flow:
                alt_warn(MSG_MissingFolderProfile.format(configfile))
                profile = {}
                break
            folderprofile = alt_input("Type the name of a profile, "+
                                      "or leave empty to cancel:\n\t> ")
            if not folderprofile:
                alt_warn(MSG_MissingFolderProfile.format(configfile))
                alt_exit(1)

    update_scope(safeget(profile,'game_dir_path',gamerel))

    global default_target
    default_target = profile.get('default_target',default_target)

    global scopemods, modsrel, modsabs, baserel, baseabs, editrel, editabs
    scopemods = safeget(profile,'folder_deployed',scopemods)
    modsrel = safeget(profile,'folder_mods',modsrel)
    baserel = safeget(profile,'folder_basecache',baserel)
    editrel = safeget(profile,'folder_editcache',editrel)

    global basedir
    basedir = (scopedir+'/'+baserel).replace("\\","/")
    if not os.path.isabs(basedir):
        basedir = os.path.join( \
            os.path.realpath(basedir) \
            , '').replace("\\","/")[:-1]
    
    global editdir
    editdir = (scopedir+'/'+editrel).replace("\\","/")
    if not os.path.isabs(editdir):
        editdir = os.path.join( \
            os.path.realpath(editdir) \
            , '').replace("\\","/")[:-1]
    
    global modsdir
    modsdir = (scopedir+'/'+modsrel).replace("\\","/")
    if not os.path.isabs(modsdir):
        modsdir = os.path.join( \
            os.path.realpath(modsdir) \
            , '').replace("\\","/")[:-1]
        
    global deploydir
    deploydir = (scopedir+'/'+scopemods).replace("\\","/")
    if not os.path.isabs(deploydir):
        deploydir = os.path.join( \
            os.path.realpath(deploydir) \
            , '').replace("\\","/")[:-1]
    
    global local_in_scope, base_in_scope, edit_in_scope, \
           mods_in_scope, deploy_in_scope, game_has_scope
    local_in_scope = base_in_scope = edit_in_scope \
                     = mods_in_scope = deploy_in_scope = None

    game_has_scope = in_scope(scopedir).message == "DirInScope"
    local_in_scope = in_scope(thisfile).message == "FileInScope"

    if not game_has_scope:
        alt_warn(MSG_GameHasNoScope.format(scopedir,scopeparent,configfile))
        if flow:
            alt_exit(1)

    base_in_scope = in_scope(basedir,True).message == "DirInScope"
    edit_in_scope = in_scope(editdir,True).message == "DirInScope"
    mods_in_scope = in_scope(basedir,True).message == "DirInScope"    
    deploy_in_scope = in_scope(deploydir,True).message == "DirInScope"
        
    if not deploy_in_scope:
        alt_warn(MSG_DeployNotInScope.format(deploydir,scopedir,configfile))
        if flow:
            alt_exit(1)

    global deploy_from_scope
    deploy_from_scope = deploydir[len(os.path.commonprefix([scopedir,deploydir]))+1:]

def configsetup(predict={},postdict={}):
    condict = YML_framework
    if yaml is not None and not cfg_overwrite:
        try:
            with open(configfile) as f:
                condict.update(yaml.load(f, Loader=yaml.FullLoader))
        except FileNotFoundError:
            pass

    dictmap(condict,predict)
    if cfg_modify:
        dictmap(condict,postdict)

    if yaml is not None:
        with open(configfile, 'w') as f:
            yaml.dump(condict, f)

    if cfg_modify:
        alt_print("Config modification successful.")
        alt_exit(0)
    
    dictmap(condict,postdict)
    configure_globals(condict)

# Private Globals

MSG_ConfigHelp = """
Create or configure a folder profile using:
 * config file (requires PyYAML): `profiles` in '{0}'
Or change the active folder profile using:
 * config file (requires PyYAML): `profile` in '{0}'
 * terminal option: --profile
Use and modify the special profile:
 * terminal options:
        --special
        --special-set <profile YAML> (requires PyYAML)
Override the game path temporarily:
 * terminal option: --game <path to game>
"""

MSG_MissingFolderProfile = """
The selected profile is not a default or configured folder profile or is configured incorrectly.
Make sure the profile is configured to the actual game directory.
Alternatively, make sure this program is in the appropriate location.
"""+MSG_ConfigHelp

MSG_GameHasNoScope = """
The folder '{0}' does not exist.
Are you sure {1} is the game's proper location?
You may need to change the path 'game_dir_path' in the profile's config.
"""+MSG_ConfigHelp.format('{2}')

MSG_DeployNotInScope = """
Deployment folder '{0}' is not a subfolder of '{1}'.
This means deploying mods is impossible!
Configure the deployment path 'folder_deployed' to be within the content.
"""+MSG_ConfigHelp.format('{2}')

MSG_CommandLineHelp = """
    -h --help
        print this help text
    -m --modify
        modify the config and halt
    -o --overwrite
        overwrite the config with default
    -s --special
        use special profile
    -l --log
        disable logging
    -e --echo
        disable echo
    -i --input
        disable input (input gets passed defaults)
    -c --config <relative file path>
        choose config file
    -H --hashes <space separated hash names>
        hashes used to compare files in edit cache (ie, "md5 sha1")
    -g --game <relative folder path>
        temporarily use a different game directory
    -p --profile <profile name>
        use a particular folder profile
    -S --special-set <profile YAML>
        map YAML to the special profile (requires PyYAML)
        
"""

default_target = []
default_priority = 100

modfile = "modfile.txt"
modfile_mlcom_start = "-:"
modfile_mlcom_end = ":-"
modfile_comment = "::"
modfile_linebreak = ";"
modfile_delimiter = ","

KWRD_to = ["To"]
KWRD_load = ["Load"]
KWRD_priority = ["Priority"]
KWRD_include = ["Include"]
KWRD_deploy = ["Deploy"]
KWRD_import = ["Import"]
KWRD_xml = ["XML"]
KWRD_sjson = ["SJSON"]

scope = "Content"
importscope = "Scripts"
localsources = {"sggmodimp.py","sjson.py","cli","yaml"}

profile_template = {
    'default_target':None,
    'game_dir_path':None,
    'folder_deployed':None,
    'folder_mods':None,
    'folder_basecache':None,
    'folder_editcache':None,
    }

default_profiles = {
    "Hades": {
        'default_target':["Scripts/RoomManager.lua"],
        },
    "Pyre": {
        'default_target':["Scripts/Campaign.lua","Scripts/MPScripts.lua"],
        },
    "Transistor": {
        'default_target':["Scripts/AllCampaignScripts.txt"],
        },
    "Bastion": {
        },
}

for k,v in default_profiles.items():
    default_profiles[k]=dictmap(profile_template.copy(),v)

YML_framework = {
    'echo':True,
    'input':True,
    'log':True,
    'hashes':hashes,
    'profile':None,
    'profile_special':profile_template,
    'profiles':default_profiles,
    'log_folder':None,
    'log_prefix':None,
    'log_suffix':None,
}

# Main Process

def start(*args,**kwargs):

    configsetup(kwargs.get('predict',{}),kwargs.get('postdict',{}))
        
    global codes
    codes = defaultdict(list)
    global todeploy
    todeploy = {}

    # remove anything in the base cache that is not in the edit cache
    alt_print("Cleaning edits... (if there are issues validate/reinstall files)")
    restorebase()

    # remove the edit cache and base cache from the last run
    def onerror(func, path, exc_info):
        if not os.access(path, os.W_OK):
            os.chmod(path, stat.S_IWUSR)
            func(path)
        else:
            raise
    rmtree(editdir, onerror)
    Path(editdir).mkdir(parents=True, exist_ok=True)
    rmtree(basedir, onerror)
    Path(basedir).mkdir(parents=True, exist_ok=True)
    Path(modsdir).mkdir(parents=True, exist_ok=True)
    Path(deploydir).mkdir(parents=True, exist_ok=True)
    
    alt_print("\nReading mod files...")
    for mod in os.scandir(modsdir):
        modfile_load(mod.path.replace("\\","/")+"/"+modfile)

    deploy_mods()
    
    alt_print("\nModified files for "+folderprofile+" mods:")
    for base, mods in codes.items():
        sort_mods(base,mods)
        make_base_edits(base,mods)

    bs = len(codes)
    ms = sum(map(len,codes.values()))

    alt_print("\n"+str(bs)+" file"+("s are"," is")[bs==1]+" modified by"
              +" a total of "+str(ms)+" mod file"+"s"*(ms!=1)+".")

def main_action(*args,**kwargs):
    try:
        start(*args,**kwargs)
    except Exception as e:
        alt_print("There was a critical error, now attempting to display the error")
        alt_print("(if this doesn't work, try again in a terminal"
                  +" which doesn't close, or check the log files)")
        logging.getLogger("MainExceptions").exception(e)
        alt_input("Press any key to see the error...")
        raise RuntimeError("Encountered uncaught exception during program") from e
    alt_input("Press any key to end program...")

def main(*args,**kwargs):
    predict = {}
    postdict = {}
    
    opts,_ = getopt(args,'hmsoleic:g:p:S:H:',
                         ['config=','log_folder=','echo','input','special',
                          'log','log-prefix=','log-suffix=','profile=,help',
                          'special-set=','game=','modify','overwrite',
                          '--hash='])

    global cfg_modify, cfg_overwrite, profile_use_special, configfile, gamerel
    
    for k,v in opts:
        if k in {'-h','--help'}:
            print(MSG_CommandLineHelp)
            return
        elif k in {'-m','--modify'}:
            cfg_modify = True
            if yaml is None:
                alt_warn("PyYAML module not found! Config cannot be written.")
        elif k in {'-o','--overwrite'}:
            cfg_overwrite = True
        elif k in {'-s','--special'}:
            profile_use_special = True
        elif k in {'-l','--log'}:
            postdict['log']
        elif k in {'-e','--echo'}:
            postdict['echo']=False
        elif k in {'-i','--input'}:
            postdict['input']=False
        elif k in {'-c','--config'}:
            configfile = v
        elif k in {'-g','--game'}:
            gamerel = v
        elif k in {'-p','--profile'}:
            postdict['profile']=v
        elif k in {'-p','--profile'}:
            postdict['hashes']=v.split(' ')
        elif k in {'-S','--special-set'}:
            if yaml is not None:
                predict.setdefault('profile_special',{})
                predict['profile_special']=yaml.load(v, Loader=yaml.FullLoader)
            else:
                alt_warn("PyYAML module not found! cannot parse command.")

    main_action(*args,predict=predict,postdict=postdict)

do_log = True
cfg_modify = False
cfg_overwrite = False
profile_use_special = False
gamerel = '..'

if __name__ == '__main__':
    do_echo = True
    do_input = True
    main(*sys.argv[1:])
else:
    do_echo = False
    do_input = False
