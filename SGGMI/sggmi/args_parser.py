from argparse import ArgumentParser


def get_parser():
    """
    Generates and returns an ArgumentParser for SGGMI.
    """
    parser = ArgumentParser(description="Process arguments for SGGMI")

    parser.add_argument(
        "-e",
        "--no-echo",
        action="store_false",
        dest="echo",
        help="Disable echo",
        default=True,
    )
    parser.add_argument(
        "-l",
        "--no-log",
        action="store_false",
        dest="log",
        help="Disable logging",
        default=True,
    )
    parser.add_argument(
        "-i",
        "--no-input",
        action="store_false",
        dest="input",
        help="Disable input (will use default values)",
        default=True,
    )

    parser.add_argument(
        "-m",
        "--modify",
        action="store_true",
        dest="modify_config",
        help="Modify the config file and halt",
    )
    parser.add_argument(
        "-o",
        "--overwrite",
        action="store_true",
        dest="overwrite_config",
        help="Overwrite the config with default",
    )

    parser.add_argument(
        "-p",
        "--profile",
        action="store",
        dest="profile",
        help="Specify which folder profile to use",
        metavar="<profile name>",
    )
    parser.add_argument(
        "-s",
        "--special",
        action="store_true",
        dest="use_special_profile",
        help="Use special profile",
    )
    parser.add_argument(
        "-S",
        "--special-set",
        action="store",
        dest="special_profile",
        help="Map json to the special profile",
        metavar="<profile json>",
    )

    parser.add_argument(
        "-c",
        "--config",
        action="store",
        dest="config_file",
        help="Use specified config file",
        metavar="<relative config path>",
    )
    parser.add_argument(
        "-g",
        "--game",
        action="store",
        dest="game_rel_dir",
        help="Temporarily use a different game directory",
        metavar="<relative game path>",
    )
    parser.add_argument(
        "-H",
        "--hashes",
        action="store",
        dest="hashes",
        help='Hashes used to compare files in edit cache (ie, "md5 sha1")',
        metavar="<space separated hash names>",
    )

    return parser