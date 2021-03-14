from pathlib import Path, PurePath


class Signal:
    truth = False
    message = None

    def __init__(self, truth=False, message=None):
        self.truth = truth
        self.message = message

    def __bool__(self):
        return self.truth

    def __eq__(self, other):
        if isinstance(other, Signal):
            return (self.truth, self.message) == (other.truth, other.message)
        return False

    def __str__(self):
        return str(self.message)

    def __repr__(self):
        return f"{self.__class__.__name__}({self.truth}, {self.message})"


def hash_file(file, out=None, modes=[], blocksize=65536):
    """
    Return file as a list of hashes
    """
    lines = []
    for mode in modes:
        hasher = hashlib.new(mode)
        with open(file, "rb") as afile:
            buf = afile.read(blocksize)
            while len(buf) > 0:
                hasher.update(buf)
                buf = afile.read(blocksize)
            lines.append(mode + "\t" + hasher.hexdigest())
    content = "\n".join(lines)
    if out:
        with open(out, "w") as ofile:
            ofile.write(content)
    return content


def is_subfile(filename, folder):
    if not filename.exists():
        return Signal(False, "DoesNotExist")

    if not filename.relative_to(folder):
        return Signal(False, "NonSub")

    if filename.is_dir():
        return Signal(False, "SubDir")

    if filename.is_file():
        return Signal(True, "SubFile")

    return Signal(False, "UnknownError")


def in_scope(filename, config, permit_DNE=False):
    if not (permit_DNE or filename.exists()):
        return Signal(False, "DoesNotExist")

    try:
        filename.relative_to(config.scope_dir)
    except ValueError:
        return Signal(False, "OutOfScope")

    try:
        filename.relative_to(config.base_cache_dir)
    except ValueError:
        pass
    else:
        return Signal(True, "InBase")

    try:
        filename.relative_to(config.edit_cache_dir)
    except ValueError:
        pass
    else:
        return Signal(True, "InEdits")

    if filename.is_dir():
        return Signal(True, "DirInScope")

    if filename.is_file():
        return Signal(True, "FileInScope")

    return Signal(False, "UnknownError")


def in_source(filename, config, permit_DNE=False):
    if not (filename.exists() or permit_DNE):
        return Signal(False, "DoesNotExist")

    if not (
        filename.relative_to(config.scope_dir)
        and config.mods_dir.relative_to(config.scope_dir)
    ):
        return Signal(False, "OutOfSource")

    if filename.is_dir():
        return Signal(True, "DirInSource")

    if filename.is_file():
        return Signal(True, "FileInSource")

    return Signal(False, "UnknownError")


def is_edited(base, config):
    edited_path = config.edit_cache_dir / f"{base}{config.edited_suffix}"
    if edited_path.is_file():
        with open(edited_path, "r") as edited_file:
            data = edited_file.read()

        return data == hash_file(PurePath.joinpath(config.scope_dir, base))
    return False


def check_scopes(config):
    game_scope = in_scope(config.scope_dir, config)
    if not game_scope.message == "DirInScope":
        print(f"FAILED {config.scope_dir} is not in scope: {game_scope.message}")
        return Signal(False, "GameNotInScope")

    deploy_scope = in_scope(config.deploy_dir, config)
    if not in_scope(config.deploy_dir, config, True).message == "DirInScope":
        print(f"FAILED {config.scope_dir} is not in scope: {deploy_scope.message}")
        return Signal(False, "DeployNotInScope")

    return Signal(True)
