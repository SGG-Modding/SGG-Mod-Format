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
    if os.path.exists(filename):
        if os.path.commonprefix([filename, folder]) == folder:
            if os.path.isfile(filename):
                return Signal(True, "SubFile")
            return Signal(False, "SubDir")
        return Signal(False, "NonSub")
    return Signal(False, "DoesNotExist")

def in_scope(filename, permit_DNE=False):
    if os.path.exists(filename) or permit_DNE:
        if local_in_scope:
            tfile = filename[len(os.path.commonprefix([filename, localdir])) :]
            tfile = tfile.split("/")[1]
            if tfile in localsources:
                return Signal(False, "IsLocalSource")
        if base_in_scope:
            if os.path.commonprefix([filename, basedir]) == basedir:
                return Signal(False, "InBase")
        if edit_in_scope:
            if os.path.commonprefix([filename, editdir]) == editdir:
                return Signal(False, "InEdits")
        if os.path.commonprefix([filename, scopedir]) == scopedir:
            if os.path.isfile(filename):
                return Signal(True, "FileInScope")
            return Signal(False, "DirInScope")
        return Signal(False, "OutOfScope")
    return Signal(False, "DoesNotExist")

def is_edited(base):
    if os.path.isfile(editdir + "/" + base + edited_suffix):
        efile = open(editdir + "/" + base + edited_suffix, "r")
        data = efile.read()
        efile.close()
        return data == hashfile(scopedir + "/" + base)
    return False