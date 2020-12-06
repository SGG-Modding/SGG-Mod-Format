import collections
import io
import sjson
import sys


def traverse(tree, key, value):
    paths = []
    iter = enumerate(tree) if isinstance(tree, list) else tree.items()
    for k, v in iter:
        if key == k and value == v:
            paths.append([k])
        if isinstance(v, collections.OrderedDict) or isinstance(v, list):
            for p in traverse(v, key, value):
                t = [k] + p
                paths.append(t)
    return paths


file = io.open(sys.argv[1], "rb")
obj = sjson.load(file)
for path in traverse(obj, sys.argv[2], sys.argv[3]):
    out = ""
    for node in path:
        out = f"{out}::{str(node)}"
    print(out[2:])
