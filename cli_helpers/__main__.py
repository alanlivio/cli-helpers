import os
import sys

if sys.platform == "win32" and hasattr(os, "add_dll_directory"):
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        for sub in ("", "PySide6", "shiboken6", "fluentqt"):
            d = os.path.join(sys._MEIPASS, sub)
            if os.path.isdir(d):
                try:
                    os.add_dll_directory(d)
                except OSError:
                    pass
    else:
        try:
            import PySide6

            os.add_dll_directory(os.path.dirname(PySide6.__file__))
        except Exception:
            pass
        try:
            import shiboken6

            os.add_dll_directory(os.path.dirname(shiboken6.__file__))
        except Exception:
            pass

from cli_helpers.gui import main

if __name__ == "__main__":
    main()
