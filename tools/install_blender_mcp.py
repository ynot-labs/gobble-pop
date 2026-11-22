import bpy
import os

ADDON_SRC = "/Users/unmercy/Documents/antig/hole/tools/blender_mcp_addon.py"
bpy.ops.preferences.addon_install(filepath=ADDON_SRC, overwrite=True)
bpy.ops.preferences.addon_enable(module="blender_mcp_addon")
bpy.ops.wm.save_userpref()
print("ENABLED_ADDONS_CHECK:", "blender_mcp_addon" in bpy.context.preferences.addons)
