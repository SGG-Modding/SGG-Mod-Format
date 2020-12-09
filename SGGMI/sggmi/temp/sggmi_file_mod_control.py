# FILE/MOD CONTROL
import os


class Signal:
    __slots__ = ["truth", "message"]

    def __init__(self, truth=False, message=None):
        object.__setattr__(self, "truth", truth)
        object.__setattr__(self, "message", message)

    def __bool__(self):
        return self.truth

    def __eq__(self, other):
        if isinstance(other, Signal):
            return (self.truth, self.message) == (other.truth, other.message)
        return False

    def __str__(self):
        return str(self.message)

    def __repr__(self):
        return (
            self.__class__.__name__
            + "("
            + self.truth.__repr__()
            + ","
            + self.message.__repr__()
            + ")"
        )

    def __setattr__(self):
        pass


hashes = ["md5"]


def hashfile(file, out=None, modes=hashes, blocksize=65536):
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


def in_source(filename, permit_DNE=False):
    if os.path.exists(filename) or permit_DNE:
        if os.path.commonprefix([filename, modsdir]) == scopedir:
            if os.path.isfile(filename):
                return Signal(True, "FileInSource")
            return Signal(False, "DirInSource")
        return Signal(False, "OutOfSource")
    return Signal(False, "DoesNotExist")


def alt_print(*args, **kwargs):
    if do_echo:
        return print(*args, **kwargs)
    if do_log:
        tlog = logsdir + "/" + "temp-" + logfile_prefix + thetime() + logfile_suffix
        f = open(tlog, "w")
        print(file=f, *args, **kwargs)
        f.close()
        f = open(tlog, "r")
        data = f.read()
        f.close()
        os.remove(tlog)
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
        tlog = logsdir + "/" + "temp-" + logfile_prefix + thetime() + logfile_suffix
        f = open(tlog, "w")
        print(file=f, *args)
        f.close()
        f = open(tlog, "r")
        data = f.read()
        f.close()
        os.remove(tlog)
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
