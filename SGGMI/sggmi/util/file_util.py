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
        return (f"{self.__class__.__name__}({self.truth}, {self.message})")

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

    if not filename.is_relative_to(folder):
        return Signal(False, "NonSub")

    if filename.is_dir():
        return Signal(False, "SubDir")

    if filename.is_file():
        return Signal(True, "SubFile")

    return Signal(False, "UnknownError")
    

def in_scope(filename, localdir, basedir, editdir, scopedir, permit_DNE=False):
    if not (filename.exists() or permit_DNE):
        return Signal(False, "DoesNotExist")

    if not filename.is_relative_to(scopedir):
        return Signal(False, "OutOfScope")

    if filename.is_relative_to(basedir):
        return Signal(True, "InBase")

    if filename.is_relative_to(editdir):
        return Signal(True, "InEdits")

    if filename.is_dir():
        return Signal(True, "DirInScope")

    if filename.is_file():
        return Signal(True, "FileInScope")

    return Signal(False, "UnknownError")


def in_source(filename, modsdir, scopedir, permit_DNE=False):
    if not (filename.exists() or permit_DNE):
        return Signal(False, "DoesNotExist")

    if not (filename.is_relative_to(scopedir) and modsdir.is_relative_to(scopedir)):
        return Signal(False, "OutOfSource")

    if filename.is_dir():
        return Signal(True, "DirInSource")

    if filename.is_file():
        return Signal(True, "FileInSource")

    return Signal(False, "UnknownError")


def is_edited(base, scopedir, editdir, edited_suffix):
    edited_path = editdir / f"{base}{edited_suffix}"
    if edited_path.is_file():
        with open(edited_path, "r") as edited_file:
            data = edited_file.read()

        return data == hash_file(PurePath.joinpath(scopedir, base))
    return False