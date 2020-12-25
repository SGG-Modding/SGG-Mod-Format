# Lua Environments
import lupa, re
from pathlib import Path, PurePath

from sggmi_file_mod_control import in_source, Signal

def is_varname(s):
    if not isinstance(s,str):
        return False
    return not (s[0].isdigit() or is_varname.banned.search(s))
is_varname.banned=re.compile(r'\s.[.].')

def copy(obj,safe=True):
    get_copy = lambda obj: object.__getattribute__(obj,"copy")
    if safe:
        try:
            return get_copy(obj)(obj)
        except AttributeError:
            return obj
    return get_copy(obj)(obj)

class node:
    _data = None
    _action = set()

    @property
    def data(self):
        return self._data
    
    @data.setter
    def data(self,data):
        self._data = data

    def __contains__(self,obj):
        k = obj in self._action
        return k

    def __iter__(self):
        return iter(self._datadict().items())

    def _datadict(self):
        if getattr(self._data,"items",None):
            return dict(self._data)
        return dict(enumerate(self._data))

    def copy(self):
        return self.__class__(copy(data))

    def items(self):
        return self._datadict().items()

    def keys(self):
        return self._datadict().keys()

    def values(self):
        return self._datadict().values()

    def get(self,key,default=None):
        return self._datadict().get(key,default)

    def __getitem__(self,key):
        return self._data[key]

    def __setitem__(self,key,value):
        self._data[key] = value

    def __delitem__(self,key):
        del self.data[key]

    def __init__(self,data):
        self._data = data

    @classmethod
    def _derive(cls,obj):
        if obj is None:
            return node_empty()
        if isinstance(obj,cls):
            return obj
        if isinstance(obj,str):
            return cls(obj)
        if isinstance(obj, type):
            return cls(obj)
        if hasattr(obj,"items"):
            return node_table(obj)
        try:
            iter(obj)
        except TypeError:
            return cls(obj)
        return node_table(obj)

class node_index(node):
    def __init__(self,data,index=None):
        self._data = data
        self._index = index

    def copy(self):
        return self.__class__(copy(self._data),self._index)
        
class node_table(node):
    _action = {"recurse"}

class node_replace(node):
    _action = {"replace"}

class node_append(node_index):
    _action = {"append"}

class node_prepend(node_index):
    _action = {"prepend"}

class node_empty(node):
    _action = {"empty"}
    def __init__(self):
        pass

class node_locked(node):
    _action = {"recurse"}
    
    def __setitem__(self,key,value):
        return

    def __delitem__(self,key,value):
        return

    @property
    def data(self):
        return copy(self._data)

    @data.setter
    def data(self,value):
        return

def recursible(obj):
    if isinstance(obj,node):
        if "recurse" in obj:
            return True
    if getattr("items",None):
        return True

class Lua:
    def __init__(self, runtime, persist=None):
        self.runtime = runtime
        self.curfile = None
        self.oldfile = None
        self.common = None
        self.context = dict(self.globals())
        self.persist = persist if persist is not None else {}
        self.meta = self.context["setmetatable"]

    def __getattr__(self, *args, **kwargs):
        try:
            return self.__getattribute__(*args, **kwargs)
        except AttributeError:
            return getattr(self.__getattribute__("runtime"), *args, **kwargs)

    def __setattr__(self, *args, **kwargs):
        try:
            return object.__setattr__(self, *args, **kwargs)
        except AttributeError:
            return setattr(self.__getattribute__("runtime"), *args, **kwargs)

    def run(lua, filename):

        try:
            with open(filename, "r") as code:

                lua.oldfile = lua.curfile
                lua.curfile = Path(filename).resolve()
                lua.curfolder = lua.curfile.parent

                lua.execute(code.read())

        except lupa._lupa.LuaError as e:
            if str(e).endswith(" assertion failed!"):
                print("---------------------------------")
                print("Assertion failed while executing " + lua.curfile)
                print(str(e).split("\n")[-1])
                print("Dumping current globals...")
                lua.dump()

    def table_replace(lua, intable, maptable):
        for k in intable.keys():
            intable[k] = None
        for k, v in maptable.items():
            intable[k] = v

    def table_insert(lua,table,index=None):
        lua.context["table"].insert(table,index)

    def table_copy(lua, table):
        return lua.table_from(dict(table))

    def table_update(lua, intable, uptable):
        dict_intable = dict(intable)
        dict_intable.update(dict(uptable))
        lua.table_replace(intable, lua.table_from(dict_intable))

    def update(lua):
        lua.table_update(lua.globals(), lua.common)

    def lock(lua, table):

        visited = lua.table()

        def visit(obj):
            visited[obj] = True
            _node = node._derive(obj)
            for k, v in _node:
                v_node = node._derive(v)
                if "recurse" in v_node:
                    if not visited[v]:
                        visit(v)
                    obj[k] = node_locked(v)
                    
        visit(table)
        
        return node_locked(table)

    def dump(lua, table=None, outer=False):
        """Dump table contents using depth first search"""

        out = []
        visited = lua.table()

        def visit(obj):
            visited[obj] = True
            visit.indent = visit.indent + 1
            if visit.indent > 0:
                out.append("{\n")
            for k, v in obj.items():
                out.append("\t" * visit.indent)
                out.append(k if is_varname(k) else "[" +repr(k)+"]")
                out.append(" = " + str(v))
                if "recurse" in node._derive(v):
                    if not visited[v]:
                        visit(v)
                out.append(",")
                out.append("\n")
            if len(list(obj.keys())):
                out.pop(-2)
            visit.indent = visit.indent - 1
            if visit.indent >= 0:
                out.append("\t" * visit.indent + "}")

        visit.indent = 0 if outer else -1

        if table is None:
            table = lua.globals()

        visit(table)
        return "".join(out)

    def define_common(lua):
        def lua_import(filename, namespace=None):

            filename = lua.curfolder / filename

            signal = Signal(True, "CheckNotIntegrated")  # in_source(filename)
            if not signal:
                return signal

            _G = lua.globals()
            old_G = lua.table_copy(_G)

            _namespace = namespace
            if namespace is None:
                _namespace = lua.table()

            lua.table_update(_namespace, lua.common)

            if namespace is None:
                lua.table_update(_namespace, _G)

            lua.table_replace(_G, _namespace)

            lua.run(filename)

            lua.table_replace(namespace, _G)

            lua.table_replace(_G, old_G)

            return signal

        def lua_print(string, end="\n", sep="\t"):
            print(string, end=end, sep=sep)

        def lua_dump(table):
            lua_print(lua.dump(table,True))

        def lua_map(intable,maptable):

            def sub_map(innode,mapnode):
                if sub_map.level[innode.data] is None:
                    sub_map.level[innode.data] = 0

                sub_map.level[innode.data]+=1
                
                for k,v in mapnode:
                    indata = node._derive(innode.data.get(k,None))
                    mapdata = node._derive(v)
                    if "recurse" in indata and "recurse" in mapdata:
                        if not sub_map.level[indata.data]:
                            sub_map(indata,mapdata)
                            continue
                    if "remove" in mapdata:
                        del indata[k]
                        continue
                    innode[k] = v
                    
                sub_map.level[innode.data]-=1

            sub_map.level = lua.table()
            sub_map(node._derive(intable),node._derive(maptable))
            
        lua.common.include = lua_import
        lua.common.print = lua_print
        lua.common.Signal = Signal
        lua.common.dump = lua_dump
        lua.common.map = lua_map
        
        lua.common.node = lua.table_from({
            "table": node_table,
            "replace": node_replace,
            "append": node_append,
            "prepend": node_prepend,
            "empty": node_empty
            })

        lua.common.games = lua.lock({
                "Hades": {
                    "targets": {
                        "lua_import": {
                            "Scripts/RoomManager.lua"
                            }
                        }
                    },
                "Pyre": {
                    "targets": {
                        "lua_import": {
                            "Scripts/Campaign.lua",
                            "Scripts/MPScripts.lua",
                            }
                        }
                    },
                "Transistor": {
                    "targets": {
                        "lua_import": {
                            "Scripts/CampaignScripts.txt",
                            }
                        }
                    },
                "Bastion": {
                    "targets": {}
                    }
            })
        
        lua.common.mods = node_locked(lua.persist.get("mods",lua.table()))

        lua.update()

def spawn_common_context(persist=None):
    def getter(obj, attr_name):
        if not attr_name.startswith("_"):
            if hasattr(obj,attr_name):
                return getattr(obj, attr_name)
            return obj[attr_name]
        raise AttributeError('not allowed to read attribute "%s"' % attr_name)

    def setter(obj, attr_name, value):
        if not attr_name.startswith("_"):
            if hasattr(obj,attr_name):
                setattr(obj, attr_name,value)
                return
            obj[attr_name]=value
            return
        raise AttributeError('not allowed to write attribute "%s"' % attr_name)

    lua = Lua(
        lupa.LuaRuntime(register_eval=False, attribute_handlers=(getter, setter)),
        persist)

    allowed_global_keys = {
        "_G",
        "assert",
        "math",
        "getmetatable",
        "ipairs",
        "next",
        "pairs",
        "python",
        "select",
        "setmetatable",
        "string",
        "table",
        "tonumber",
        "tostring",
        "type",
    }

    _G = lua.globals()

    py = lua.globals().python
    del py.builtins

    for key in list(_G):
        if key not in allowed_global_keys:
            del _G[key]

    lua.common = lua.table_copy(_G)

    lua.define_common()

    return lua


def spawn_context_loading(persist=None):
    lua = spawn_common_context(persist)

    def mod_set_name(mod,name,codename):
        mod.info.name = name
        mod.info.codename = codename

    def mod_set_info(mod,info):
        mod.info = info

    def mod_add_payload(mod,method,source,targets=None):
        lua.table_insert(mod.payloads,lua.table_from({
            "method": lua.common.payloads[method],
            "source": source,
            "targets": mod.defaults.targets if targets is None else targets
            }))
    
    mod_meta = lua.table_from({
            "__index": {
                "map": lua.common.map,
                "setName": mod_set_name,
                "setInfo": mod_set_info,
                "addPayload": mod_add_payload
            }
        })

    mod_base = lua.table_from({
            "priority": 100,
            "info": lua.table(),
            "relations": lua.table(),
            "payloads": lua.table(),
            "defaults": lua.table()
        })

    lua.common.mod = lua.meta(lua.table(),mod_meta)

    lua.update()

    return lua


def spawn_context_action(persist=None):
    lua = spawn_common_context(persist)

    data = lua.table()
    lua.common.data = data
    data.input = lua.table()
    data.output = lua.table()
    data.messages = lua.table()

    lua.update()

    return lua
