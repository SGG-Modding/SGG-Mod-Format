__all__ = [
    "sjson_safeget",
    "sjson_clearDNE",
    "sjson_read",
    "sjson_write",
    "sjson_map",
    "sjson_merge",
]

KWRD_sjson = ["SJSON"]

## SJSON Handling
try:
    import sjson  # pip: SJSON
except ModuleNotFoundError:
    sjson = None

from collections import OrderedDict

## SJSON mapping

if sjson is not None:

    sjson_RESERVED_sequence = "_sequence"
    sjson_RESERVED_append = "_append"
    sjson_RESERVED_replace = "_replace"
    sjson_RESERVED_delete = "_delete"

    def sjson_safeget(data, key):
        if isinstance(data, list):
            if isinstance(key, int):
                if key < len(data) and key >= 0:
                    return data[key]
            return DNE
        if isinstance(data, OrderedDict):
            return util.get_attribute(key, DNE)
        return DNE

    def sjson_clearDNE(data):
        if isinstance(data, OrderedDict):
            for k, v in data.items():
                if v is DNE:
                    del data[k]
                    continue
                data[k] = sjson_clearDNE(v)
        if isinstance(data, list):
            L = []
            for i, v in enumerate(data):
                if v is DNE:
                    continue
                L.append(sjson_clearDNE(v))
            data = L
        return data

    def sjson_read(filename):
        try:
            return sjson.loads(open(filename).read().replace("\\", "\\\\"))
        except sjson.ParseException as e:
            alt_print(repr(e))
            return DNE

    def sjson_write(filename, content):
        if not isinstance(filename, str):
            return
        if isinstance(content, OrderedDict):
            content = sjson.dumps(content)
        else:
            content = ""
        with open(filename, "w") as f:
            s = "{\n" + content + "}"

            # Indentation styling
            p = ""
            S = ""
            for c in s:
                if c in ("{", "[") and p in ("{", "["):
                    S += "\n"
                if c in ("}", "]") and p in ("}", "]"):
                    S += "\n"
                S += c
                if p in ("{", "[") and c not in ("{", "[", "\n"):
                    S = S[:-1] + "\n" + S[-1]
                if c in ("}", "]") and p not in ("}", "]", "\n"):
                    S = S[:-1] + "\n" + S[-1]
                p = c
            s = S.replace(", ", "\n").split("\n")
            i = 0
            L = []
            for S in s:
                for c in S:
                    if c in ("}", "]"):
                        i = i - 1
                L.append("  " * i + S)
                for c in S:
                    if c in ("{", "["):
                        i = i + 1
            s = "\n".join(L)

            f.write(s)

    def sjson_map(indata, mapdata):
        if mapdata is DNE:
            return indata
        if sjson_safeget(mapdata, sjson_RESERVED_sequence):
            S = []
            for k, v in mapdata.items():
                try:
                    d = int(k) - len(S)
                    if d >= 0:
                        S.extend([DNE] * (d + 1))
                    S[int(k)] = v
                except ValueError:
                    continue
            mapdata = S
        if type(indata) == type(mapdata):
            if sjson_safeget(mapdata, 0) != sjson_RESERVED_append or isinstance(
                mapdata, OrderedDict
            ):
                if isinstance(mapdata, list):
                    if sjson_safeget(mapdata, 0) == sjson_RESERVED_delete:
                        return DNE
                    if sjson_safeget(mapdata, 0) == sjson_RESERVED_replace:
                        del mapdata[0]
                        return mapdata
                    indata.expand([DNE] * (len(mapdata) - len(indata)))
                    for k, v in enumerate(mapdata):
                        indata[k] = sjson_map(sjson_safeget(indata, k), v)
                else:
                    if sjson_safeget(mapdata, sjson_RESERVED_delete):
                        return DNE
                    if sjson_safeget(mapdata, sjson_RESERVED_replace):
                        del mapdata[sjson_RESERVED_replace]
                        return mapdata
                    for k, v in mapdata.items():
                        indata[k] = sjson_map(sjson_safeget(indata, k), v)
                return indata
            elif isinstance(mapdata, list):
                for i in range(1, len(mapdata)):
                    indata.append(mapdata[i])
                return indata
        else:
            return mapdata
        return mapdata

    def sjson_merge(infile, mapfile):
        indata = sjson_read(infile)
        if mapfile:
            mapdata = sjson_read(mapfile)
        else:
            mapdata = DNE
        indata = sjson_map(indata, mapdata)
        indata = sjson_clearDNE(indata)
        sjson_write(infile, indata)