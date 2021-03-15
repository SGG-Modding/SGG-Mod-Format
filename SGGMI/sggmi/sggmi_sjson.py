__all__ = [
    "get_attribute",
    "read",
    "write",
    "sjson_map",
    "sjson_merge",
]

try:
    import sjson
except Exception as e:
    print("Could not import sjson, skipping sjson edits.")

from collections import OrderedDict
import os

import util

KEYWORD = "SJSON"
RESERVED = {
    "sequence": "_sequence",
    "append": "_append",
    "replace": "_replace",
    "delete": "_delete",
}


def read_file(filename):
    try:
        with open(filename, "r") as file_in:
            file_data = file_in.read().replace("\\", "\\\\")
        return sjson.loads(file_data)
    except sjson.ParseException as e:
        alt_print(e, config=config)
    except FileNotFoundError:
        alt_print(f"sggmi_sjson (read_file): {filename} does not exist!", config=config)
    except Exception as e:
        alt_print(e, config=config)

    return None


def write_file(filename, content):
    if not Path(filename).exists():
        alt_print(f"sggmi_sjson (write_file): {filename} not found!", config=config)
        return

    if not Path(filename).is_file():
        alt_print(f"sggmi_sjson (write_file): {filename} is not a file!", config=config)
        return

    if isinstance(content, OrderedDict):
        content = sjson.dumps(content)
    else:
        content = ""

    curr_string = "{\n" + content + "}"
    output = ""

    # Indentation styling
    prev_char = ""
    for char in curr_string:
        if (char in "{[" and prev_char in "{[") or (char in "}]" and prev_char in "}]"):
            output += "\n"

        output += char

        if (char not in "{[\n" and prev_char in "{[") or (
            char in "}]" and prev_char not in "}]\n"
        ):
            output = output[:-1] + "\n" + output[-1]

        prev_char = char

    TEMP_output_split = output.replace(", ", "\n").split("\n")
    indent = 0
    output_lines = []
    for line in TEMP_output_split:
        for char in line:
            if char in "}]":
                indent -= 1

        output_lines.append("  " * indent + line)
        for char in line:
            if char in "{[":
                indent += 1

    final_output = "\n".join(output_lines)

    try:
        with open(filename, "w") as file_out:
            file_out.write(final_output)
    except Exception as e:
        alt_print(f"sggmi_sjson (write_file): \n{e}", config=config)


def merge_data(base_data, input_data):
    if not input_data:
        return base_data

    if util.get_attribute(input_data, RESERVED["sequence"]):
        new_sequence = []
        for key, value in input_data.items():
            try:
                d = int(k) - len(S)
                if d >= 0:
                    new_sequence.extend([DNE] * (d + 1))
                new_sequence[int(k)] = v
            except ValueError:
                continue
        input_data = S

    if type(base_data) == type(input_data):
        if util.get_attribute(input_data, 0) != RESERVED["append"] or isinstance(
            input_data, OrderedDict
        ):
            if isinstance(input_data, list):
                if util.get_attribute(input_data, 0) == RESERVED["delete"]:
                    return None

                if util.get_attribute(input_data, 0) == RESERVED["replace"]:
                    del input_data[0]
                    return input_data

                base_data.expand([DNE] * (len(input_data) - len(base_data)))
                for idx, value in enumerate(input_data):
                    base_data[idx] = merge_data(
                        util.get_attribute(base_data, idx), value
                    )

            else:
                if util.get_attribute(input_data, RESERVED["delete"]):
                    return None

                if util.get_attribute(input_data, RESERVED["replace"]):
                    del input_data[RESERVED["replace"]]
                    return input_data

                for key, value in input_data.items():
                    base_data[key] = merge_data(
                        util.get_attribute(base_data, key), value
                    )

            return base_data

        elif isinstance(input_data, list):
            for elem in input_data[1:]:
                base_data.append(elem)

            return base_data

    return input_data


def merge_files(base_file, input_file, overwrite_base=True):
    if not input_file:
        return base_file

    base_data = read_file(base_file)
    input_data = read_file(input_file)

    merged_data = merge_data(base_data, input_data)
    prune(merged_data)

    if overwrite_base:
        write_file(base_file, merged_data)
