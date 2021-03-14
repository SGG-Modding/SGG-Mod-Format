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
    # modules
    "logging",
    "xml",
    "sjson",
    "json",
    "hashlib",
]
__version__ = "1.0a-r4"
__author__ = "Andre Issa"

# Dependencies

import os, sys, stat
import logging
import json
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
    sggmi_xml,
)
from sggmi.config import SggmiConfiguration
from sggmi.util import (
    alt_exit,
    alt_input,
    alt_open,
    alt_print,
    alt_warn,
)

## LUA import statement adding
def lua_addimport(base, path):
    with open(base, "a") as basefile:
        basefile.write(f"\nImport {path}")


####################
# Mod File Control #
####################


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
        path = PurePath.joinpath(config.scope_dir, scopepath)
        if util.in_scope(
            path,
            config.local_dir,
            config.base_cache_dir,
            config.edit_cache_dir,
            config.scope_dir,
        ):
            args = [tokens[i::n] for i in range(n)]
            for i in range(len(args[-1])):
                sources = [
                    PurePath.joinpath(reldir, arg[i].replace('"', "")) for arg in args
                ]
                paths = []
                num = -1
                for source in sources:
                    if PurePath.joinpath(config.mods_dir, source).is_dir():
                        tpath = []
                        for entry in PurePath.joinpath(
                            config.mods_dir, source
                        ).iterdir():
                            if util.in_scope(
                                entry,
                                config.local_dir,
                                config.base_cache_dir,
                                config.edit_cache_dir,
                                config.scope_dir,
                            ):
                                tpath.append(entry.as_posix())
                        paths.append(tpath)
                        if num > len(tpath) or num < 0:
                            num = len(tpath)
                    elif util.in_scope(
                        PurePath.joinpath(config.mods_dir, source),
                        config.local_dir,
                        config.base_cache_dir,
                        config.edit_cache_dir,
                        config.scope_dir,
                    ):
                        paths.append(
                            PurePath.joinpath(config.mods_dir, source)
                            .resolve()
                            .as_posix()
                        )
                if paths:
                    for j in range(abs(num)):
                        sources = [x[j] if isinstance(x, list) else x for x in paths]
                        for src in sources:
                            todeploy[src] = util.merge_dict(todeploy.get(src), cfg)
                        f = lambda x: map(
                            lambda y: PurePath.joinpath(config.deploy_rel_dir, y), x
                        )
                        codes[scopepath].append(
                            Mod(
                                "\n".join(
                                    [
                                        Path(source).resolve().as_posix()
                                        for source in sources
                                    ]
                                ),
                                tuple(f(sources)),
                                mode,
                                scopepath,
                                len(codes[scopepath]),
                                **load,
                            )
                        )


def modfile_load(filename, config):
    if util.is_subfile(filename, config.mods_dir).message == "SubDir":
        for entry in Path(filename).iterdir():
            modfile_load(entry, config)
        return

    rel_name = filename.relative_to(config.mods_dir)
    try:
        file = alt_open(filename, "r")
    except IOError:
        return

    if config.echo:
        alt_print(rel_name, config=config)

    reldir = rel_name.parent
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
                    modfile_load(PurePath.joinpath(reldir, s.replace('"', "")), config)

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
                    reldir,
                    tokens[len(sggmi_xml.KEYWORD) :],
                    to,
                    1,
                    "xml",
                    cfg,
                    priority=p,
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


def deploy_mods(todeploy, config):
    for file_path in todeploy.keys():
        PurePath.joinpath(
            config.deploy_dir,
            Path(file_path).resolve().parent.relative_to(config.mods_dir),
        ).mkdir(parents=True, exist_ok=True)

        copyfile(
            Path(file_path),
            PurePath.joinpath(
                config.deploy_dir, Path(file_path).relative_to(config.mods_dir)
            ),
        )


def sort_mods(base, mods, codes):
    codes[base].sort(key=lambda x: x.load["priority"])
    for i in range(len(mods)):
        mods[i].id = i


def make_base_edits(base, mods, config):
    PurePath.joinpath(config.base_cache_dir, Path(base).parent).mkdir(
        parents=True, exist_ok=True
    )
    copyfile(
        PurePath.joinpath(config.scope_dir, base),
        PurePath.joinpath(config.base_cache_dir, base),
    )

    if config.echo:
        i = 0
        alt_print(f"\n{base}", config=config)

    try:
        for mod in mods:
            if mod.mode == "lua":
                lua_addimport(
                    PurePath.joinpath(config.scope_dir, base),
                    mod.data[0],
                )
            elif mod.mode == "xml":
                sggmi_xml.merge(
                    PurePath.joinpath(config.scope_dir, base),
                    mod.data[0],
                )
            elif mod.mode == "sjson":
                sggmi_sjson.merge_files(
                    PurePath.joinpath(config.scope_dir, base),
                    mod.data[0],
                )
            if config.echo:
                k = i + 1
                for s in mod.src.split("\n"):
                    i += 1
                    alt_print(
                        f" #{i}"
                        + " +" * (k < i)
                        + " " * ((k >= i) + 5 - len(str(i)))
                        + f"{Path(s).relative_to(config.mods_dir)}",
                        config=config,
                    )
    except Exception as e:
        copyfile(
            PurePath.joinpath(config.base_cache_dir, base),
            PurePath.joinpath(config.scope_dir, base),
        )
        raise RuntimeError(
            "Encountered uncaught exception while implementing mod changes"
        ) from e

    PurePath.joinpath(config.edit_cache_dir, Path(base).parent).mkdir(
        parents=True, exist_ok=True
    )
    util.hash_file(
        PurePath.joinpath(config.base_cache_dir, base),
        PurePath.joinpath(config.edit_cache_dir, f"{base}{config.edited_suffix}"),
    )


def cleanup(target, config):
    if not target and target.exists():
        return True

    if target.is_dir():
        empty = True
        for entry in target.iterdir():
            if cleanup(entry, config):
                empty = False
        if empty:
            target.rmdir()
            return False
        return True

    target_relative_to_base_cache_dir = target.relative_to(config.base_cache_dir)
    if PurePath.joinpath(config.scope_dir, target_relative_to_base_cache_dir).is_file():
        if util.is_edited(target_relative_to_base_cache_dir, config):
            copyfile(
                target,
                PurePath.joinpath(config.scope_dir, target_relative_to_base_cache_dir),
            )

        if config.echo:
            alt_print(target_relative_to_base_cache_dir, config=config)

        target.unlink()
        return False
    return True


def restorebase(config):
    if not cleanup(config.base_cache_dir, config):
        try:
            copy_tree(config.base_cache_dir, config.base_cache_dir)
        except DistutilsFileError:
            pass


# Global Preprocessing


def thetime():
    return datetime.now().strftime("%d.%m.%Y-%I.%M%p-%S.%f")


def preplogfile(config):
    if config.log:
        config.logs_dir.mkdir(parents=True, exist_ok=True)
        logging.basicConfig(
            filename=config.logs_dir
            / f"{config.logs_prefix}{thetime()}{config.logs_suffix}",
            level=logging.INFO,
        )
    logging.captureWarnings(config.log and not config.echo)


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


# Main Process
def start(config):
    codes = defaultdict(list)
    todeploy = {}

    # remove anything in the base cache that is not in the edit cache
    alt_print(
        "\nCleaning edits... (if there are issues validate/reinstall files)",
        config=config,
    )
    restorebase(config)

    # remove the edit cache and base cache from the last run
    def on_error(func, path, exc_info):
        if not os.access(path, os.W_OK):
            os.chmod(path, stat.S_IWUSR)
            func(path)
        else:
            raise

    rmtree(config.edit_cache_dir, on_error)
    rmtree(config.base_cache_dir, on_error)

    config.edit_cache_dir.mkdir(parents=True, exist_ok=True)
    config.base_cache_dir.mkdir(parents=True, exist_ok=True)
    config.mods_dir.mkdir(parents=True, exist_ok=True)
    config.deploy_dir.mkdir(parents=True, exist_ok=True)

    alt_print("\nReading mod files...", config=config)
    for mod in config.mods_dir.iterdir():
        modfile_load(mod / config.mod_file, config)

    deploy_mods(config)

    alt_print(f"\nModified files for {config.chosen_profile} mods:", config=config)
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
        + ".",
        config=config,
    )


def main_action(config):
    try:
        start(config)
    except Exception as e:
        alt_print(
            "There was a critical error, now attempting to display the error",
            config=config,
        )
        alt_print(
            "(if this doesn't work, try again in a terminal"
            + " which doesn't close, or check the log files)",
            config=config,
        )
        logging.getLogger("MainExceptions").exception(e)
        alt_input("Press any key to see the error...", config=config)
        raise RuntimeError("Encountered uncaught exception during program") from e

    alt_input("Press any key to end program...", config=config)


if __name__ == "__main__":
    config = SggmiConfiguration()

    parser = args_parser.get_parser()
    parsed_args = parser.parse_args()
    config.apply_command_line_arguments(parsed_args)

    scopes_okay = util.check_scopes(config)
    if not scopes_okay:
        if scopes_okay.message == "GameHasNoScope":
            alt_warn(
                messages.game_has_no_scope(
                    config.scope_dir, config.scope_dir.parent, config.config_file
                )
            )

        if scopes_okay.message == "DeployNotInScope":
            alt_warn(
                messages.deploy_not_in_scope(
                    config.deploy_dir, config.scope_dir, config.config_file
                )
            )

        alt_exit(1, config=config)

    if config.modify_config:
        alt_print("Config modification successful.", config=config)
        alt_exit(0, config=config)

    main_action(config)
