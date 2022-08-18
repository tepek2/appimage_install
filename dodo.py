from dataclasses import field
import os
import re
from doit.action import CmdAction

TARGET_DIR = "~/bin"
KEBAB_CASE_REGEX_FILE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*(\.sh)$")


def copy_utils():
    if "utils" not in os.listdir("./"):
        return ""
    create_utils_folder = f"mkdir -p {TARGET_DIR}/utils"
    copy_utils = f"cp ./utils/* {TARGET_DIR}/utils"
    return "\n".join(
        [
            create_utils_folder,
            copy_utils,
        ]
    )


def copy_scripts():
    return_cmd = ""
    folder_content = os.listdir("./")
    for item in folder_content:
        if re.match(KEBAB_CASE_REGEX_FILE, item):
            script_name = item.replace(".sh", "")
            return_cmd += f"""
                cp ./{item} {TARGET_DIR}/{script_name}
                chmod +x {TARGET_DIR}/{script_name}
            """

    return return_cmd


def task_save_script():
    return {
        "actions": [
            CmdAction(copy_utils()),
            CmdAction(copy_scripts()),
        ],
        "verbosity": 2,
    }
