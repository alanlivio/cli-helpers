import os
import sys

if sys.platform == "win32" and hasattr(os, "add_dll_directory"):
    meipass = getattr(sys, "_MEIPASS", None)
    if meipass:
        for sub in ("", "PySide6", "shiboken6", "fluentqt"):
            d = os.path.join(meipass, sub)
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
