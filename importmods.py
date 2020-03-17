#Mod importer for SuperGiant Games modding format
#Place in the 'Content' folder
#Place mod lua files in Content/Mods/#modname#/Scripts
#   Add "-- IMPORT @ DEFAULT" to the start of them
#       where DEFAULT can also be swapped with a path relative to Content/Scripts

import os
from collections import defaultdict
from pathlib import Path

home = "Scripts"
mods = "Mods"
modsrel = ".."
header = "-- IMPORT @"
defaultcode = "DEFAULT"
importkey = "-- AUTOMATIC MOD IMPORTS BEGIN"
warning = "-- ANYTHING BELOW THIS POINT WILL BE DELETED"
importkeyword = "Import "
postword = "if ModUtil then if ModUtil.CollapseMarked then ModUtil.CollapseMarked() end end"
importend = "-- AUTOMATIC MOD IMPORTS END"
bakdir = "Backup"
baktype = ".bak"

defaults = {"Hades":"\"RoomManager.lua\"",
            "Pyre":"\"Campaign.lua\"",
            "Transistor":"\"AllCampaignScripts.txt\""}

gamepath = os.path.abspath('..')
default = defaults[gamepath.replace("\\","/").split("/")[-1]]

codes = defaultdict(list)
for mod in os.scandir(mods):
    for script in os.scandir(mod.path+"/"+home):
        path = script.path.replace("\\","/")
        with open(script.path,'r') as file:
            for line in file:
                if line[:len(header)]==header:
                    code = line[len(header)+1:].replace("\n","")
                    if code == defaultcode:
                        code = default
                    codes[home+"/"+code.replace("\"","")].append(modsrel+"/"+path)
                break

for base, mods in codes.items():
    keyfound = False
    lines = []
    with open(base,'r') as basefile:
        for line in basefile:
            if line[:-1] == importkey:
                keyfound = True
                break
            lines.append(line)
    Path(bakdir+"/"+home).mkdir(parents=True, exist_ok=True)
    backupfile = open(bakdir+"/"+base+baktype,'w')
    for line in lines:
        backupfile.write(line)
    backupfile.close()
    if keyfound:
        basefile = open(base,'w')
        for line in lines:
            basefile.write(line)
    else:
        basefile = open(base,'a')
    basefile.write(importkey+"\n")
    basefile.write(warning+"\n")
    print(base)
    for mod in mods:
        print("    \""+mod+"\"")
        basefile.write(importkeyword+"\""+mod+"\""+"\n")
    basefile.write(postword+"\n")
    basefile.write(importend+"\n")
    basefile.close()
