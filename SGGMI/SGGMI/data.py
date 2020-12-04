__all__ = [
    "get_attribute",
    "set_attribute",
    "merge_dict",
]


def get_attribute(data, key, default=None):
    """
    Return value at 'key' from dictionary, list, or tuple

    Arguments:
    data -- dictionary, list, or tuple to get value at 'key' from
    key -- index or key to get from 'data'

    Keyword Arguments:
    default -- value to return if no value is found at 'key' (Default: None)

    Returns:
    Value at 'key' or provided 'default' value
    """
    result = default

    if (
        (isinstance(data, list) or isinstance(data, tuple))
        and isinstance(key, int)
        and 0 <= key < len(data)
    ):
        result = data[key]

    if isinstance(data, dict) and key in data:
        result = data[key]

    if result is None:
        result = default

    return result


def set_attribute(data, key, value):
    """
    Set value at 'key' in a dictionary or list

    Arguments:
    data -- dictionary or list to modify
    key -- index or key to set in 'data'
    value -- value to store at 'key' in 'data'

    Returns:
    True if value was updated
    """
    if isinstance(data, list) and isinstance(key, int) and 0 <= key < len(data):
        data[key] = value
        return True

    if isinstance(data, dict):
        data[key] = value
        return True

    return False


def merge_dict(base_dict, input_dict, modify_original=True):
    """
    Merge input_dict into base_dict, overwriting entries in base_dict as needed.

    Arguments:
    base_dict -- dictionary to start with
    input_dict -- dictionary to merge into base_dict

    Keyword Arguments:
    modify_original -- If False, original base_dict is left intact (Default: True)

    Returns:
    Resulting dictionary after merging
    """
    # Check if anything needs to be done first
    if not base_dict:
        return input_dict

    if not input_dict:
        return base_dict

    # Create new dict if modify_original is False
    target_dict = dict(base_dict) if not modify_original else base_dict

    for key in input_dict:
        if key not in target_dict:
            target_dict[key] = input_dict[key]
            continue

        # If both are dictionaries, need to merge recursively
        if isinstance(target_dict[key], dict) and isinstance(input_dict[key], dict):
            merge_dict(target_dict[key], input_dict[key])
        # If they're the same, no need to update
        elif target_dict[key] == input_dict[key]:
            pass  # same leaf value
        else:
            target_dict[key] = input_dict[key]

    return target_dict
