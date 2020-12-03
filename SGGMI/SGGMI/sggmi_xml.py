__all__ = [
    "get",
    "get",
    "write",
    "xml_map",
    "merge",
]

## XML Handling
import xml.etree.ElementTree as xml

RESERVED = {
    "replace": "_replace",
    "delete": "_delete",
}

KEYWORD = "XML"

def get(data, key):
    if isinstance(data, list):
        if isinstance(key, int):
            if key < len(data) and key >= 0:
                return data[key]
        return DNE
    if isinstance(data, xml.ElementTree):
        root = data.getroot()
        if root:
            return root.get(k, DNE)
    if isinstance(data, xml.Element):
        return data.get(key, DNE)
    return DNE


def read(filename):
    try:
        return xml.parse(filename)
    except xml.ParseError:
        return DNE


def write(filename, content, start=None):
    if not isinstance(filename, str):
        return
    if not isinstance(content, xml.ElementTree):
        return
    content.write(filename)

    # Indentation styling
    data = ""
    if start:
        data = start
    with open(filename, "r") as file:
        i = 0
        for line in file:
            nl = False
            if len(line.replace("\t", "").replace(" ", "")) > 1:
                q = True
                p = ""
                for s in line:
                    if s == '"':
                        q = not q
                    if p == "<" and q:
                        if s == "/":
                            i -= 1
                            data = data[:-1]
                        else:
                            i += 1
                        data += p
                    if s == ">" and p == "/" and q:
                        i -= 1
                    if p in (" ") or (s == ">" and p == '"') and q:
                        data += "\n" + "\t" * (i - (s == "/"))
                    if s not in (" ", "\t", "<") or not q:
                        data += s
                    p = s
    open(filename, "w").write(data)


def xml_map(indata, mapdata):
    if mapdata is DNE:
        return indata
    if type(indata) == type(mapdata):
        if isinstance(mapdata, dict):
            for k, v in mapdata.items():
                indata[k] = xml_map(indata.get(k), v)
            return indata
        if isinstance(mapdata, xml.ElementTree):
            root = xml_map(indata.getroot(), mapdata.getroot())
            if root:
                indata._setroot(root)
            return indata
        elif isinstance(mapdata, xml.Element):
            mtags = dict()
            for v in mapdata:
                if not mtags.get(v.tag, False):
                    mtags[v.tag] = True
            for tag in mtags:
                mes = mapdata.findall(tag)
                ies = indata.findall(tag)
                for i, me in enumerate(mes):
                    ie = get(ies, i)
                    if ie is DNE:
                        indata.append(me)
                        continue
                    if me.get(RESERVED["delete"], None) not in {
                        None,
                        "0",
                        "false",
                        "False",
                    }:
                        indata.remove(ie)
                        continue
                    if me.get(RESERVED["replace"], None) not in {
                        None,
                        "0",
                        "false",
                        "False",
                    }:
                        ie.text = me.text
                        ie.tail = me.tail
                        ie.attrib = me.attrib
                        del ie.attrib[RESERVED["replace"]]
                        continue
                    ie.text = xml_map(ie.text, me.text)
                    ie.tail = xml_map(ie.tail, me.tail)
                    ie.attrib = xml_map(ie.attrib, me.attrib)
                    xml_map(ie, me)
            return indata
        return mapdata
    else:
        return mapdata
    return mapdata


def merge(infile, mapfile):
    start = ""
    with open(infile, "r") as file:
        for line in file:
            if line[:5] == "<?xml" and line[-3:] == "?>\n":
                start = line
                break
    indata = get(infile)
    if mapfile:
        mapdata = get(mapfile)
    else:
        mapdata = DNE
    indata = xml_map(indata, mapdata)
    write(infile, indata, start)
