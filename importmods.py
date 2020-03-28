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
priorityh = "-- PRIORITY "
importkey = "-- AUTOMATIC MOD IMPORTS BEGIN"
warning = "-- ANYTHING BELOW THIS POINT WILL BE DELETED"
importkeyword = "Import "
postword = "if ModUtil then if ModUtil.CollapseMarked then ModUtil.CollapseMarked() end end"
importend = "-- AUTOMATIC MOD IMPORTS END"
bakdir = "Backup"
baktype = ""

defaults = {"Hades":"\"RoomManager.lua\"",
            "Pyre":"\"Campaign.lua\"",
            "Transistor":"\"AllCampaignScripts.txt\""}

class modcode():
    ep = 100
    ap = None
    before = None
    after = None
    rbefore = None
    rafter = None
    def __init__(self,path,key,index):
        self.path = path
        self.key = key
        self.id = index


def strup(string):
    return string[0].upper()+string[1:]

gamedir = os.path.join(os.path.realpath(".."), '')
game = strup(gamedir.replace("\\","/").split("/")[-2])
default = defaults[game]

def in_directory(file):
    #https://stackoverflow.com/questions/3812849/how-to-check-whether-a-directory-is-a-sub-directory-of-another-directory
    if not os.path.isfile(file):
        return False
    file = os.path.realpath(file)
    if strup(file.replace("\\","/").split("/")[-2]) != home:
        return False
    return os.path.commonprefix([file, gamedir]) == gamedir

def valid_scan(file):
    if os.path.exists(file):
        if os.path.isdir(file):
            return True
    return False

codes = defaultdict(list)
for mod in os.scandir(mods):
    if valid_scan(mod.path+"/"+home):
        for script in os.scandir(mod.path+"/"+home):
            path = script.path.replace("\\","/")
            code = ""
            with open(script.path,'r') as file:
                linum = 0
                for line in file:
                    linum += 1
                    if linum == 1:
                        if line[:len(header)]==header:
                            code = line[len(header)+1:].replace("\n","")
                            if code == defaultcode:
                                code = default
                            code = home+"/"+code.replace("\"","")
                            if in_directory(code):
                                codes[code].append(modcode(modsrel+"/"+path,code,len(codes[code])))
                            continue
                        else:
                            break
                    if linum == 2:
                        if line[:len(priorityh)]==priorityh:
                            try:
                                codes[code][-1].ep = int(line[len(priorityh):][:-1])
                            except:
                                pass
                        break
                    break

for base, mods in codes.items():
    codes[base].sort(key=lambda x: x.ep)
    for i in range(len(mods)):
        mods[i].id=i

print("Adding import statements for "+game+" mods...")

for base, mods in codes.items():
    keyfound = False
    lines = []
    with open(base,'r') as basefile:
        for line in basefile:
            if line[:-1] == importkey:
                keyfound = True
                break
            lines.append(line)
    Path(bakdir+"/"+"/".join(base.split("/")[:-1])).mkdir(parents=True, exist_ok=True)
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
        basefile.write("\n")
    basefile.write(importkey+"\n")
    basefile.write(warning+"\n")
    print("\n"+"/".join(base.split("/")[1:]))
    i = 0
    for mod in mods:
        i+=1
        print(" #"+str(i)+" "*(6-len(str(i)))+mod.path)
        basefile.write(importkeyword+"\""+mod.path+"\""+"\n")
    basefile.write(postword+"\n")
    basefile.write(importend+"\n")
    basefile.close()
print("\n"+str(len(codes))+" files import a total of "+str(sum(map(len,codes.values())))+" mods.")

if __name__ == '__main__':
    input("Press any key to end program...")
