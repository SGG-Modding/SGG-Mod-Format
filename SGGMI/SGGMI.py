"""
Mod Importer for SuperGiant Games' Games

https://github.com/MagicGonads/sgg-mod-format
"""

__all__ = [
    # functions
    "main",
    "configure_globals",
    "start",
    "preplogfile",
    "cleanup",
    "hashfile",
    "lua_addimport",
    # variables
    "configfile",
    "logfile_prefix",
    "logfile_suffix",
    "edited_suffix",
    "scopemods",
    "modsrel",
    "baserel",
    "editrel",
    "logsrel",
    "gamerel",
    "do_log",
    "cfg_modify",
    "cfg_overwrite",
    "profile_use_special",
    # modules
    "logging",
    "xml",
    "sjson",
    "json",
    "hashlib",
    # other
    "DNE",
]
__version__ = "1.0a-r4"
__author__ = "Andre Issa"

# Dependencies

import os, sys, stat
import logging
import json
import warnings
import hashlib
from pathlib import Path, PurePath
from shutil import copyfile, rmtree
from datetime import datetime
from collections import defaultdict
from distutils.dir_util import copy_tree
from distutils.errors import DistutilsFileError

from sggmi import (
  args_parser,
  util,
  sggmi_sjson,
  sggmi_xml
)

# Configurable Globals

configfile = "miconfig.json"
#### These are better configured using the config file to be specific to different installs
scopemods = "Deploy"  # Must be accessible to game scope
modsrel = "Mods"
baserel = "Base Cache"
editrel = "Edit Cache"
logsrel = "Logs"
logfile_prefix = "log-modimp "
logfile_suffix = ".txt"
edited_suffix = ".hash"

# Data Functionality

DNE = ()  # 'Does Not Exist' singleton

## LUA import statement adding


def lua_addimport(base, path):
    with open(base, "a") as basefile:
        basefile.write(f"\nImport {path}")


# FILE/MOD CONTROL

hashes = ["md5"]


def alt_open(*args, **kwargs):
    return open(*args, encoding="utf-8-sig", **kwargs)


def alt_print(*args, **kwargs):
    if do_echo:
        return print(*args, **kwargs)
    if do_log:
        tlog = logsdir / f"temp-{logfile_prefix}{thetime()}{logfile_suffix}"
        with alt_open(tlog, "w") as temp_file:
            print(file=temp_file, *args, **kwargs)

        with alt_open(tlog, "r") as temp_file:
            data = temp_file.read()

        tlog.unlink()
        return logging.getLogger(__name__).info(data)


def alt_warn(message):
    warnings.warn(message, stacklevel=2)
    if do_log and do_echo:
        logging.getLogger(__name__).warning(message)


def alt_input(*args, **kwargs):
    if do_echo:
        if do_input:
            return input(*args)
        print(*args)
        return kwargs.get("default", None)
    if do_log:
        tlog = logsdir / f"temp-{logfile_prefix}{thetime()}{logfile_suffix}"
        with alt_open(tlog, "w") as temp_file:
            print(file=temp_file, *args)

        with alt_open(tlog, "r") as temp_file:
            data = temp_file.read()

        tlog.unlink()
        logging.getLogger(__name__).info(data)

        if do_input:
            return input()
        return kwargs.get("default", None)


def alt_exit(code=None):
    alt_input("Press any key to end program...")
    exit(code)


def modfile_splitlines(body):
    glines = map(lambda s: s.strip().split('"'), body.split("\n"))
    lines = []
    li = -1
    mlcom = False

    def gp(group, lines, li, mlcom, even):
        if mlcom:
            tgroup = group.split(modfile_mlcom_end, 1)
            if len(tgroup) == 1:  # still commented, carry on
                even = not even
                return (lines, li, mlcom, even)
            else:  # comment ends, if a quote, even is disrupted
                even = False
                mlcom = False
                group = tgroup[1]
        if even:
            lines[li] += '"' + group + '"'
        else:
            tgroup = group.split(modfile_comment, 1)
            tline = tgroup[0].split(modfile_mlcom_start, 1)
            tgroup = tline[0].split(modfile_linebreak)
            lines[li] += tgroup[0]  # uncommented line
            for g in tgroup[1:]:  # new uncommented lines
                lines.append(g)
                li += 1
            if len(tline) > 1:  # comment begins
                mlcom = True
                lines, li, mlcom, even = gp(tline[1], lines, li, mlcom, even)
        return (lines, li, mlcom, even)

    for groups in glines:
        even = False
        li += 1
        lines.append("")
        for group in groups:
            lines, li, mlcom, even = gp(group, lines, li, mlcom, even)
            even = not even
    return lines


def modfile_tokenise(line):
    groups = line.strip().split('"')
    for i, group in enumerate(groups):
        if i % 2:
            groups[i] = [group]
        else:
            groups[i] = group.replace(" ", modfile_delimiter)
            groups[i] = groups[i].split(modfile_delimiter)
    tokens = []
    for group in groups:
        for x in group:
            if x != "":
                tokens.append(x)
    return tokens


class Mod:
    """ modcode data structure """

    mode = ""

    def __init__(self, src, data, mode, key, index, **load):
        self.src = src
        self.data = data
        self.mode = mode
        self.key = key
        self.id = index
        self.load = {"priority": default_priority}
        self.load.update(load)


# FILE/MOD LOADING


def modfile_startswith(tokens, keyword, n):
    return tokens[: len(keyword)] == keyword and len(tokens) >= len(keyword) + 1


def modfile_loadcommand(reldir, tokens, to, n, mode, cfg={}, **load):
    for scopepath in to:
        path = PurePath.joinpath(scopedir, scopepath)
        if util.in_scope(path, localdir, basedir, editdir, scopedir):
            args = [tokens[i::n] for i in range(n)]
            for i in range(len(args[-1])):
                sources = [
                    PurePath.joinpath(reldir, arg[i].replace('"', ""))
                    for arg in args
                ]
                paths = []
                num = -1
                for source in sources:
                    if PurePath.joinpath(modsdir, source).is_dir():
                        tpath = []
                        for entry in PurePath.joinpath(modsdir, source).iterdir():
                            if util.in_scope(entry, localdir, basedir, editdir, scopedir):
                                tpath.append(entry.as_posix())
                        paths.append(tpath)
                        if num > len(tpath) or num < 0:
                            num = len(tpath)
                    elif util.in_scope(PurePath.joinpath(modsdir, source), localdir, basedir, editdir, scopedir):
                        paths.append(PurePath.joinpath(modsdir, source).resolve().as_posix())
                if paths:
                    for j in range(abs(num)):
                        sources = [x[j] if isinstance(x, list) else x for x in paths]
                        for src in sources:
                            todeploy[src] = util.merge_dict(todeploy.get(src), cfg)
                        f = lambda x: map(lambda y: PurePath.joinpath(deploy_from_scope, y), x)
                        codes[scopepath].append(
                            Mod(
                                "\n".join([Path(source).resolve().as_posix() for source in sources]),
                                tuple(f(sources)),
                                mode,
                                scopepath,
                                len(codes[scopepath]),
                                **load
                            )
                        )


def modfile_load(filename, echo=True):
    if util.is_subfile(filename, modsdir).message == "SubDir":
        for entry in Path(filename).iterdir():
            modfile_load(entry, echo)
        return

    relname = filename.relative_to(modsdir)
    try:
        file = alt_open(filename, "r")
    except IOError:
        return

    if echo:
        alt_print(relname)

    reldir = relname.parent
    p = default_priority
    to = default_target
    cfg = {}

    with file:
        for line in modfile_splitlines(file.read()):
            tokens = modfile_tokenise(line)
            if len(tokens) == 0:
                continue

            elif modfile_startswith(tokens, KWRD_to, 0):
                to = [Path(s).as_posix() for s in tokens[1:]]
                if len(to) == 0:
                    to = default_target

            elif modfile_startswith(tokens, KWRD_load, 0):
                n = len(KWRD_load) + len(KWRD_priority)
                if tokens[len(KWRD_load) : n] == KWRD_priority:
                    if len(tokens) > n:
                        try:
                            p = int(tokens[n])
                        except ValueError:
                            pass
                    else:
                        p = default_priority

            if modfile_startswith(tokens, KWRD_include, 1):
                for s in tokens[1:]:
                    modfile_load(
                        PurePath.joinpath(reldir, s.replace('"', "")),
                        echo
                    )

            elif modfile_startswith(tokens, KWRD_deploy, 1):
                for token in tokens[1:]:
                    check = util.is_subfile(s, modsdir)
                    if check:
                        todeploy[s] = util.merge_dict(todeploy.get(s), cfg)
                    elif check.message == "SubDir":
                        for entry in Path(s).iterdir():
                            S = entry.resolve().as_posix()
                            todeploy[S] = util.merge_dict(todeploy.get(S), cfg)

            elif modfile_startswith(tokens, KWRD_import, 1):
                modfile_loadcommand(
                    reldir,
                    tokens[len(KWRD_import) :],
                    to,
                    1,
                    "lua",
                    cfg,
                    priority=p,
                )
            elif modfile_startswith(tokens, sggmi_xml.KEYWORD, 1):
                modfile_loadcommand(
                    reldir, tokens[len(sggmi_xml.KEYWORD) :], to, 1, "xml", cfg, priority=p
                )
            elif modfile_startswith(tokens, sggmi_sjson.KEYWORD, 1):
                if sjson:
                    modfile_loadcommand(
                        reldir,
                        tokens[len(sggmi_sjson.KEYWORD) :],
                        to,
                        1,
                        "sjson",
                        cfg,
                        priority=p,
                    )

                else:
                    alt_warn("SJSON module not found! Skipped command: " + line)


def deploy_mods():
    for file_path in todeploy.keys():
        PurePath.joinpath(deploydir, Path(file_path).resolve().parent.relative_to(modsdir)).mkdir(
            parents=True, exist_ok=True
        )

        copyfile(
            Path(file_path),
            PurePath.joinpath(deploydir, Path(file_path).relative_to(modsdir)),
        )


def sort_mods(base, mods):
    codes[base].sort(key=lambda x: x.load["priority"])
    for i in range(len(mods)):
        mods[i].id = i


def make_base_edits(base, mods, echo=True):
    PurePath.joinpath(basedir, Path(base).parent).mkdir(
        parents=True, exist_ok=True
    )
    copyfile(
        PurePath.joinpath(scopedir, base),
        PurePath.joinpath(basedir, base),
    )

    if echo:
        i = 0
        alt_print("\n" + base)

    try:
        for mod in mods:
            if mod.mode == "lua":
                lua_addimport(
                    PurePath.joinpath(scopedir, base),
                    mod.data[0],
                )
            elif mod.mode == "xml":
                sggmi_xml.merge(
                    PurePath.joinpath(scopedir, base),
                    mod.data[0],
                )
            elif mod.mode == "sjson":
                sggmi_sjson.merge_files(
                    PurePath.joinpath(scopedir, base),
                    mod.data[0],
                )
            if echo:
                k = i + 1
                for s in mod.src.split("\n"):
                    i += 1
                    alt_print(
                        f" #{i}"
                        + " +" * (k < i)
                        + " " * ((k >= i) + 5 - len(str(i)))
                        + f"{Path(s).relative_to(modsdir)}"
                    )
    except Exception as e:
        copyfile(
            PurePath.joinpath(basedir, base),
            PurePath.joinpath(scopedir, base),
        )
        raise RuntimeError(
            "Encountered uncaught exception while implementing mod changes"
        ) from e

    PurePath.joinpath(editdir, Path(base).parent).mkdir(
        parents=True, exist_ok=True
    )
    util.hash_file(
        PurePath.joinpath(scopedir, base),
        PurePath.joinpath(editdir, f"{base}{edited_suffix}")
    )


def cleanup(target=None, echo=True):
    if not target.exists():
        return True

    if target.is_dir():
        empty = True
        for entry in target.iterdir():
            if cleanup(entry, echo):
                empty = False
        if empty:
            target.rmdir()
            return False
        return True

    target_relative_to_basedir = target.relative_to(basedir)
    if PurePath.joinpath(scopedir, target_relative_to_basedir).is_file():
        if util.is_edited(target_relative_to_basedir, scopedir, editdir, edited_suffix):
            copyfile(
                target,
                PurePath.joinpath(scopedir, target_relative_to_basedir),
            )

        if echo:
            alt_print(target_relative_to_basedir)

        target.unlink()
        return False
    return True


def restorebase(echo=True):
    if not cleanup(basedir, echo):
        try:
            copy_tree(basedir, scopedir)
        except DistutilsFileError:
            pass


# Global Preprocessing


def thetime():
    return datetime.now().strftime("%d.%m.%Y-%I.%M%p-%S.%f")


def preplogfile():
    if do_log:
        logsdir.mkdir(parents=True, exist_ok=True)
        logging.basicConfig(
            filename=logsdir / f"{logfile_prefix}{thetime()}{logfile_suffix}",
            level=logging.INFO,
        )
    logging.captureWarnings(do_log and not do_echo)


def update_scope(rel=".."):
    global gamedir
    gamedir = Path(rel).resolve()
    global scopeparent
    scopeparent = gamedir.name
    global scopedir
    scopedir = PurePath.joinpath(gamedir, scope)


def configure_globals(condict={}, flow=True):

    global do_echo, do_log, do_input
    do_echo = util.get_attribute(condict, "echo", do_echo)
    do_log = util.get_attribute(condict, "log", do_log)
    do_input = util.get_attribute(condict, "input", do_input)

    global logsrel, logfile_prefix, logfile_suffix
    logsrel = util.get_attribute(condict, "log_folder", logsrel)
    logfile_prefix = util.get_attribute(condict, "log_prefix", logfile_prefix)
    logfile_suffix = util.get_attribute(condict, "log_suffix", logfile_suffix)

    global logsdir
    logsdir = Path(logsrel).resolve().parent
    preplogfile()

    global hashes
    hashes = util.get_attribute(condict, "hashes", hashes)

    global thisfile, localdir, localparent
    thisfile = Path(__file__).resolve()
    localdir = thisfile.parent
    localparent = localdir.parent

    global profiles, profile, folderprofile
    profiles = {}
    profiles.update(util.get_attribute(condict, "profiles", {}))
    profile = None

    folderprofile = util.get_attribute(condict, "profile", localparent)
    if profile_use_special:
        profile = util.get_attribute(condict, "profile_special", profile)
    while profile is None:
        profile = util.get_attribute(profiles, folderprofile, None)
        if profile is None:
            if not flow:
                alt_warn(MSG_MissingFolderProfile.format(configfile))
                profile = {}
                break
            folderprofile = alt_input(
                "Type the name of a profile, " + "or leave empty to cancel:\n\t> "
            )
            if not folderprofile:
                alt_warn(MSG_MissingFolderProfile.format(configfile))
                alt_exit(1)

    update_scope(util.get_attribute(profile, "game_dir_path", gamerel))

    global default_target
    default_target = profile.get("default_target", default_target)

    global scopemods, modsrel, modsabs, baserel, baseabs, editrel, editabs
    scopemods = util.get_attribute(profile, "folder_deployed", scopemods)
    modsrel = util.get_attribute(profile, "folder_mods", modsrel)
    baserel = util.get_attribute(profile, "folder_basecache", baserel)
    editrel = util.get_attribute(profile, "folder_editcache", editrel)

    global basedir, editdir, modsdir, deploydir
    basedir = PurePath.joinpath(scopedir, baserel).resolve() 
    editdir = PurePath.joinpath(scopedir, editrel).resolve()
    modsdir = PurePath.joinpath(scopedir, modsrel).resolve()
    deploydir = PurePath.joinpath(scopedir, scopemods).resolve()

    game_has_scope = util.in_scope(scopedir, localdir, basedir, editdir, scopedir).message == "DirInScope"
    local_in_scope = util.in_scope(thisfile, localdir, basedir, editdir, scopedir).message == "FileInScope"

    if not game_has_scope:
        alt_warn(MSG_GameHasNoScope.format(scopedir, scopeparent, configfile))
        if flow:
            alt_exit(1)

    if not util.in_scope(deploydir, localdir, basedir, editdir, scopedir, True).message == "DirInScope":
        alt_warn(MSG_DeployNotInScope.format(deploydir, scopedir, configfile))
        if flow:
            alt_exit(1)

    global deploy_from_scope
    deploy_from_scope = deploydir.relative_to(scopedir)

def configsetup(predict={}, postdict={}):
    condict = CFG_framework
    if not cfg_overwrite:
        try:
            with alt_open(configfile) as f:
                condict.update(json.load(f))
        except FileNotFoundError:
            pass

    util.merge_dict(condict, predict)
    if cfg_modify:
        util.merge_dict(condict, postdict)

    with alt_open(configfile, "w") as f:
        json.dump(condict, f, indent=1)

    if cfg_modify:
        alt_print("Config modification successful.")
        alt_exit(0)

    util.merge_dict(condict, postdict)
    configure_globals(condict)


# Private Globals

MSG_ConfigHelp = """
Create or configure a folder profile using:
 * config file: `profiles` in '{0}'
Or change the active folder profile using:
 * config file: `profile` in '{0}'
 * terminal option: --profile
Use and modify the special profile:
 * terminal options:
        --special
        --special-set <profile json>
Override the game path temporarily:
 * terminal option: --game <path to game>
"""

MSG_MissingFolderProfile = (
    """
The selected profile is not a default or configured folder profile or is configured incorrectly.
Make sure the profile is configured to the actual game directory.
Alternatively, make sure this program is in the appropriate location.
"""
    + MSG_ConfigHelp
)

MSG_GameHasNoScope = """
The folder '{0}' does not exist.
Are you sure {1} is the game's proper location?
You may need to change the path 'game_dir_path' in the profile's config.
""" + MSG_ConfigHelp.format(
    "{2}"
)

MSG_DeployNotInScope = """
Deployment folder '{0}' is not a subfolder of '{1}'.
This means deploying mods is impossible!
Configure the deployment path 'folder_deployed' to be within the content.
""" + MSG_ConfigHelp.format(
    "{2}"
)

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

scope = "Content"
importscope = "Scripts"
localsources = {"sggmi"}

profile_template = {
    "default_target": None,
    "game_dir_path": None,
    "folder_deployed": None,
    "folder_mods": None,
    "folder_basecache": None,
    "folder_editcache": None,
}

default_profiles = {
    "Hades": {
        "default_target": ["Scripts/RoomManager.lua"],
    },
    "Pyre": {
        "default_target": ["Scripts/Campaign.lua", "Scripts/MPScripts.lua"],
    },
    "Transistor": {
        "default_target": ["Scripts/AllCampaignScripts.txt"],
    },
    "Bastion": {},
}

for k, v in default_profiles.items():
    default_profiles[k] = util.merge_dict(
        profile_template.copy(), v, modify_original=False
    )

CFG_framework = {
    "echo": True,
    "input": True,
    "log": True,
    "hashes": hashes,
    "profile": None,
    "profile_special": profile_template,
    "profiles": default_profiles,
    "log_folder": None,
    "log_prefix": None,
    "log_suffix": None,
}

# Main Process


def start(*args, **kwargs):

    configsetup(kwargs.get("predict", {}), kwargs.get("postdict", {}))

    global codes
    codes = defaultdict(list)
    global todeploy
    todeploy = {}

    # remove anything in the base cache that is not in the edit cache
    alt_print("\nCleaning edits... (if there are issues validate/reinstall files)")
    restorebase()

    # remove the edit cache and base cache from the last run
    def on_error(func, path, exc_info):
        if not os.access(path, os.W_OK):
            os.chmod(path, stat.S_IWUSR)
            func(path)
        else:
            raise

    rmtree(editdir, on_error)
    rmtree(basedir, on_error)

    editdir.mkdir(parents=True, exist_ok=True)
    basedir.mkdir(parents=True, exist_ok=True)
    modsdir.mkdir(parents=True, exist_ok=True)
    deploydir.mkdir(parents=True, exist_ok=True)

    alt_print("\nReading mod files...")
    for mod in modsdir.iterdir():
        modfile_load(mod / modfile)

    deploy_mods()

    alt_print("\nModified files for " + folderprofile + " mods:")
    for base, mods in codes.items():
        sort_mods(base, mods)
        make_base_edits(base, mods)

    bs = len(codes)
    ms = sum(map(len, codes.values()))

    alt_print(
        "\n"
        + str(bs)
        + " file"
        + ("s are", " is")[bs == 1]
        + " modified by"
        + " a total of "
        + str(ms)
        + " mod file"
        + "s" * (ms != 1)
        + "."
    )


def main_action(*args, **kwargs):
    try:
        start(*args, **kwargs)
    except Exception as e:
        alt_print("There was a critical error, now attempting to display the error")
        alt_print(
            "(if this doesn't work, try again in a terminal"
            + " which doesn't close, or check the log files)"
        )
        logging.getLogger("MainExceptions").exception(e)
        alt_input("Press any key to see the error...")
        raise RuntimeError("Encountered uncaught exception during program") from e
    alt_input("Press any key to end program...")


def main(*args, **kwargs):
    predict = {}
    postdict = {}

    global cfg_modify, cfg_overwrite, profile_use_special, configfile, gamerel

    parser = args_parser.get_parser()
    parsed_args = vars(parser.parse_args())

    # This section is to take the parsed arguments and convert them to the
    # current globals system. Once the config module is complete, this section
    # will go away.
    postdict["echo"] = parsed_args["echo"]
    postdict["log"] = parsed_args["log"]
    postdict["input"] = parsed_args["input"]

    if parsed_args["profile"]:
        postdict["profile"] = parsed_args["profile"]

    if parsed_args["use_special_profile"]:
        profile_use_special = parsed_args["use_special_profile"]

    if parsed_args["special_profile"]:
        predict.setdefault("profile_special", {})
        predict["profile_special"] = json.loads(parsed_args["special_profile"])

    cfg_modify = parsed_args["modify_config"]
    cfg_modify = parsed_args["overwrite_config"]

    if parsed_args["config_file"]:
        configfile = Path(parsed_args["config_file"])

    if parsed_args["game_dir"]:
        gamerel = Path(parsed_args["game_dir"])

    if parsed_args["hashes"]:
        postdict["hashes"] = parsed_args["hashes"].split(" ")

    main_action(*args, predict=predict, postdict=postdict)


do_log = True
cfg_modify = False
cfg_overwrite = False
profile_use_special = False
gamerel = ".."

if __name__ == "__main__":
    do_echo = True
    do_input = True
    main(*sys.argv[1:])
else:
    do_echo = False
    do_input = False
