"""Open the default terminal in a local folder, without shell interpolation."""
import shutil

import gi

gi.require_version("Nautilus", "4.1")
from gi.repository import Gio, GObject, Nautilus


class OpenTerminalHere(GObject.GObject, Nautilus.MenuProvider):
    def _items(self, folder):
        path = folder.get_location().get_path() if folder.is_directory() else None
        terminal = shutil.which("xdg-terminal-exec")
        if not path or not terminal:
            return []
        item = Nautilus.MenuItem(
            name="OmarchySetup::OpenTerminalHere",
            label="Open Terminal Here",
            tip="Open the default terminal in this folder",
            icon="utilities-terminal",
        )
        item.connect("activate", self._activate, terminal, path)
        return [item]

    def _activate(self, _item, terminal, path):
        launcher = Gio.SubprocessLauncher.new(Gio.SubprocessFlags.NONE)
        launcher.set_cwd(path)
        launcher.spawnv([terminal, "--dir=" + path])

    def get_background_items(self, folder):
        return self._items(folder)

    def get_file_items(self, files):
        return self._items(files[0]) if len(files) == 1 else []
