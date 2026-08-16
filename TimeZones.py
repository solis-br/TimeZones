#!/usr/bin/env python3

import sys
import json
import argparse
from pathlib import Path
from zoneinfo import ZoneInfo
from datetime import datetime

from PySide6.QtWidgets import QApplication, QWidget, QVBoxLayout, QHBoxLayout, QLabel
from PySide6.QtCore import Qt, QTimer

CFG = Path.home() / "TimeZones.json"


def load():
    if CFG.exists():
        return json.loads(CFG.read_text())

    return {
        "zones": [
            {"label": "Hawaii","zone": "Pacific/Honolulu"},
            {"label": "Aleutian","zone": "America/Adak"},
            {"label": "Alaska","zone": "America/Anchorage"},
            {"label": "Pacific",     "zone": "America/Los_Angeles"},
            {"label": "Arizona",     "zone": "America/Phoenix"},
            {"label": "Mountain",    "zone": "America/Denver"},
            {"label": "Central",     "zone": "America/Chicago"},
            {"label": "Eastern",     "zone": "America/New_York"},
            {"label": "Atlantic",     "zone": "America/Halifax"},
            {"label": "UTC",         "zone": "Etc/UTC"},
            {"label": "London",      "zone": "Europe/London"},
            {"label": "Queensland",  "zone": "Australia/Brisbane"}
        ]
    }


def save(cfg):
    CFG.write_text(json.dumps(cfg, indent=2))


class W(QWidget):
    def __init__(self, horizontal=False):
        super().__init__()

        self.cfg = load()

        self.setWindowTitle("Time Zones")

        try:
            self.local_zone = (
                Path("/etc/localtime")
                .resolve()
                .relative_to("/usr/share/zoneinfo")
                .as_posix()
            )
        except Exception:
            tz = datetime.now().astimezone().tzinfo
            self.local_zone = getattr(tz, "key", str(tz))

        print(f"Local timezone: {self.local_zone}")

        layout = QVBoxLayout(self)

        if horizontal:
            self.list = QHBoxLayout()
        else:
            self.list = QVBoxLayout()

        layout.addLayout(self.list)

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.refresh)
        self.timer.start(30000)

        self.refresh()

    def refresh(self):
        while self.list.count():
            item = self.list.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        for entry in self.cfg["zones"]:
            dt = datetime.now(ZoneInfo(entry["zone"]))

            if entry["zone"] == self.local_zone:
                title = f"<b>{entry['label']} (Local)</b>"
                style = """
                    QLabel {
                        font-size: 25px;
                        background-color: goldenrod;
                        color: black;
                        border: 2px solid #b8860b;
                        border-radius: 6px;
                        padding: 10px;
                    }
                """
            else:
                title = f"<b>{entry['label']}</b>"
                style = """
                    QLabel {
                        font-size: 20px;
                        border: 1px solid gray;
                        border-radius: 6px;
                        padding: 10px;
                    }
                """

            text = (
                f"{title}<br>"
                f"{dt.strftime('%A')}<br>"
                f"{dt.strftime('%B %d, %Y')}<br>"
                f"{dt.strftime('%I:%M %p')}"
            )

            label = QLabel(text)
            label.setAlignment(Qt.AlignmentFlag.AlignCenter)
            label.setStyleSheet(style)

            self.list.addWidget(label)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="World Clock")
    parser.add_argument(
        "-H",
        "--horizontal",
        action="store_true",
        help="Display clocks horizontally"
    )

    args = parser.parse_args()

    app = QApplication(sys.argv)

    window = W(horizontal=args.horizontal)
    window.show()

    sys.exit(app.exec())
