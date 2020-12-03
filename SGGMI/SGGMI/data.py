__all__ = [
    "safeget",
    "safeset",
    "dictmap",
]

def safeget(data, key, default=DNE, skipnone=True):
    if data is None:
        data = globals()
    if isinstance(data, list) or isinstance(data, tuple):
        if isinstance(key, int):
            if key < len(data) and key >= 0:
                ret = data[key]
                return default if skipnone and ret is None else ret
        return default
    if isinstance(data, dict):
        ret = data.get(key, default)
        return default if skipnone and ret is None else ret
    return default


def safeset(data, key, value):
    if data is None:
        data = globals()
    if isinstance(data, list):
        if isinstance(key, int):
            if key < len(data) and key >= 0:
                data[key] = value
    if isinstance(data, dict):
        data[key] = value


def dictmap(indict, mapdict):
    if mapdict is DNE or mapdict is indict:
        return indict
    if type(indict) == type(mapdict):
        if isinstance(mapdict, dict):
            for k, v in mapdict.items():
                indict[k] = dictmap(safeget(indict, k), v)
            return indict
    return mapdict