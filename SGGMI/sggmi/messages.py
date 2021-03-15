def config_help(config_file):
    return f"""
Create or configure a folder profile using:
 * config file: `profiles` in '{config_file}'
Or change the active folder profile using:
 * config file: `profile` in '{config_file}'
 * terminal option: --profile
Use and modify the special profile:
 * terminal options:
        --special
        --special-set <profile json>
Override the game path temporarily:
 * terminal option: --game <path to game>
"""


def missing_folder_profile(config_file):
    return """
The selected profile is not a default or configured folder profile or is configured incorrectly.
Make sure the profile is configured to the actual game directory.
Alternatively, make sure this program is in the appropriate location.
""" + config_help(
        config_file
    )


def game_has_no_scope(scope_dir, config_file):
    return f"""
The folder '{scope_dir}' does not exist.
Are you sure {scope_dir.parent} is the game's proper location?
You may need to change the path 'game_dir_path' in the profile's config.
""" + config_help(
        config_file
    )


def deploy_not_in_scope(deploy_dir, scope_dir, config_file):
    return f"""
Deployment folder '{deploy_dir}' is not a subfolder of '{scope_dir}'.
This means deploying mods is impossible!
Configure the deployment path 'folder_deployed' to be within the content.
""" + config_help(
        config_file
    )