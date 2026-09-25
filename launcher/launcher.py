#!/usr/bin/env python3
"""
ghOSt Launcher
Keyboard, mouse, and controller launcher for the uConsole display
SDL2-based, Wayland/Cage compatible
"""

import os
import sys
import subprocess
import threading
import json
import time
import signal
import shutil
from pathlib import Path

try:
    import sdl2
    import sdl2.ext
    import sdl2.sdlttf as ttf
    import sdl2.sdlimage as img
    import ctypes
except ImportError:
    print("SDL2 not found, install python3-sdl2")
    sys.exit(1)

# =============================================================================
# CONFIGURATION
# =============================================================================
SCREEN_W, SCREEN_H = 1280, 720
FPS = 30
FONT_PATH = "/usr/share/fonts/X11/misc/ter-x14b.pcf.gz"
FONT_SIZE = 14

# Default launcher palette
COLORS = {
    "bg":        (30,  30,  46,  255),   # #1e1e2e
    "surface0":  (49,  50,  68,  255),   # #313244
    "surface1":  (69,  71,  90,  255),   # #45475a
    "overlay":   (108, 112, 134, 255),   # #6c7086
    "text":      (205, 214, 244, 255),   # #cdd6f4
    "subtext":   (166, 173, 200, 255),   # #a6adc8
    "blue":      (137, 180, 250, 255),   # #89b4fa
    "green":     (166, 227, 161, 255),   # #a6e3a1
    "red":       (243, 139, 168, 255),   # #f38ba8
    "yellow":    (249, 226, 175, 255),   # #f9e2af
    "mauve":     (203, 166, 247, 255),   # #cba6f7
    "teal":      (148, 226, 213, 255),   # #94e2d5
    "pink":      (245, 194, 231, 255),   # #f5c2e7
    "peach":     (250, 179, 135, 255),   # #fab387
}

CATEGORY_HINTS = {
    "SIGNAL INT": "RF and signal-analysis tools, local dashboards, and SDR workflows.",
    "RECON": "Network discovery, enumeration, traffic inspection, and offensive tooling.",
    "WIRELESS": "Wi-Fi and Bluetooth utilities, adapters, and monitor-mode workflows.",
    "TOOLS": "Analysis, reversing, cracking, and browser-based helper utilities.",
    "AI": "Voice and text access to the local ghOSt AI assistant.",
    "PRIVACY": "Tor, VPN, encrypted DNS, and privacy-preserving network paths.",
    "BROWSER": "Lightweight graphical and terminal browsers for local and remote work.",
    "GAMES": "Optional stealth and retro extras kept separate from the main workflow.",
    "TERMINAL": "Shells, tmux, editors, file managers, and system monitors.",
    "DISPLAY": "Internal panel and external display management for HDMI or docks.",
    "ANDROID": "ADB, scrcpy, static analysis, and Android debugging helpers.",
    "CAMERA": "Camera, ffmpeg, and Kinect capture or testing utilities.",
    "COMMS": "Email, IRC, RSS, and other operator communications tools.",
    "POWER": "Battery, performance, and thermal-profile controls for the platform.",
    "THEMES": "Wallpaper and palette switching for the launcher and lock screen.",
    "SYSTEM": "Wi-Fi, SSH keys, Syncthing, reboot, and power-off actions.",
}

# =============================================================================
# MENU STRUCTURE
# =============================================================================
MENU_TEMPLATE = [
    {
        "label": "SIGNAL INT",
        "icon": "📡",
        "color": "teal",
        "items": [
            {"label": "INTERCEPT",      "cmd": "netsurf-gtk http://localhost:5050",  "icon": "🔭", "requires": {"paths": ["/opt/ghost/intercept/intercept.py"]}},
            {"label": "SDR++ Brown",    "cmd": "sdrpp",                              "icon": "📻", "requires": {"commands": ["sdrpp"]}},
            {"label": "dump1090 ADS-B", "cmd": "foot dump1090 --interactive",        "icon": "✈️", "requires": {"commands": ["dump1090"]}},
            {"label": "Kismet",         "cmd": "foot kismet",                        "icon": "📶", "requires": {"commands": ["kismet"]}},
            {"label": "inspectrum",     "cmd": "inspectrum",                         "icon": "🔬", "requires": {"commands": ["inspectrum"]}},
            {"label": "fldigi",         "cmd": "fldigi",                             "icon": "📟", "requires": {"commands": ["fldigi"]}},
        ]
    },
    {
        "label": "RECON",
        "icon": "🔍",
        "color": "yellow",
        "items": [
            {"label": "nmap scan",      "cmd": "foot fish -C 'nmap -sV -sC '",       "icon": "🗺️"},
            {"label": "bettercap",      "cmd": "foot sudo bettercap",                "icon": "🕸️"},
            {"label": "termshark",      "cmd": "foot sudo termshark -i any",         "icon": "🦈"},
            {"label": "Metasploit",     "cmd": "foot sudo msfconsole",               "icon": "💀"},
            {"label": "sqlmap",         "cmd": "foot sqlmap --wizard",               "icon": "💉"},
            {"label": "mitmproxy",      "cmd": "foot mitmproxy",                     "icon": "🎭"},
        ]
    },
    {
        "label": "WIRELESS",
        "icon": "📶",
        "color": "blue",
        "items": [
            {"label": "airmon-ng",      "cmd": "foot sudo airmon-ng",               "icon": "🔓"},
            {"label": "airodump-ng",    "cmd": "foot sudo airodump-ng",             "icon": "📡"},
            {"label": "wifite2",        "cmd": "foot sudo wifite",                  "icon": "🔑"},
            {"label": "airgeddon",      "cmd": "foot sudo bash /opt/ghost/airgeddon/airgeddon.sh", "icon": "⚡", "requires": {"paths": ["/opt/ghost/airgeddon/airgeddon.sh"]}},
            {"label": "wavemon",        "cmd": "foot wavemon",                      "icon": "〰️"},
            {"label": "bluetuith",      "cmd": "foot bluetuith",                    "icon": "🔵", "requires": {"commands": ["bluetuith"]}},
        ]
    },
    {
        "label": "TOOLS",
        "icon": "🛠️",
        "color": "mauve",
        "items": [
            {"label": "CyberChef",      "cmd": "netsurf-gtk http://localhost:8000",  "icon": "🧪"},
            {"label": "radare2",        "cmd": "foot r2",                            "icon": "🔧"},
            {"label": "hashcat",        "cmd": "foot hashcat",                       "icon": "🔐"},
            {"label": "john",           "cmd": "foot john",                          "icon": "🗝️"},
            {"label": "SpiderFoot",     "cmd": "foot spiderfoot -l 127.0.0.1:5001", "icon": "🕷️", "requires": {"commands": ["spiderfoot"]}},
            {"label": "x64dbg",         "cmd": "wine /opt/ghost/wine-apps/x64dbg/x64/x64dbg.exe", "icon": "🐛", "requires": {"commands": ["wine"], "paths": ["/opt/ghost/wine-apps/x64dbg/x64/x64dbg.exe"]}},
        ]
    },
    {
        "label": "AI",
        "icon": "🤖",
        "color": "pink",
        "items": [
            {"label": "hey (voice)",    "cmd": "foot hey",                           "icon": "🎙️", "requires": {"commands": ["hey"]}},
            {"label": "hey (text)",     "cmd": "foot hey -t",                        "icon": "💬", "requires": {"commands": ["hey"]}},
            {"label": "hey (model)",    "cmd": "foot hey -m",                        "icon": "⚙️", "requires": {"commands": ["hey"]}},
        ]
    },
    {
        "label": "PRIVACY",
        "icon": "👻",
        "color": "overlay",
        "items": [
            {"label": "Tor Browser",    "cmd": "foot torsocks w3m https://check.torproject.org", "icon": "🧅"},
            {"label": "anonsurf on",    "cmd": "foot sudo anonsurf start",           "icon": "🔒", "requires": {"commands": ["anonsurf"]}},
            {"label": "anonsurf off",   "cmd": "foot sudo anonsurf stop",            "icon": "🔓", "requires": {"commands": ["anonsurf"]}},
            {"label": "WireGuard",      "cmd": "foot sudo wg-quick up wg0",          "icon": "🛡️"},
            {"label": "ProtonVPN",      "cmd": "foot sudo protonvpn-cli connect",    "icon": "⚡", "requires": {"commands": ["protonvpn-cli"]}},
            {"label": "i2pd",           "cmd": "foot sudo systemctl start i2pd",     "icon": "🌐", "requires": {"commands": ["i2pd"]}},
        ]
    },
    {
        "label": "BROWSER",
        "icon": "🌐",
        "color": "blue",
        "items": [
            {"label": "NetSurf",        "cmd": "netsurf-gtk https://start.duckduckgo.com", "icon": "🌊"},
            {"label": "w3m",            "cmd": "foot w3m https://start.duckduckgo.com",    "icon": "📄"},
            {"label": "w3m Tor",        "cmd": "foot torsocks w3m https://3g2upl4pq6kufc4m.onion", "icon": "🧅"},
        ]
    },
    {
        "label": "GAMES",
        "icon": "🎮",
        "color": "peach",
        "items": [
            {"label": "PortMaster",     "cmd": "/opt/portmaster/PortMaster.sh",      "icon": "🎮", "requires": {"paths": ["/opt/portmaster/PortMaster.sh"]}},
            {"label": "DOSBox-X",       "cmd": "dosbox-x /opt/ghost/dosbox/ghost.conf", "icon": "💾", "requires": {"commands": ["dosbox-x"]}},
            {"label": "Rockbox",        "cmd": "/opt/portmaster/ports/Rockbox/Rockbox.sh", "icon": "🎵", "requires": {"paths": ["/opt/portmaster/ports/Rockbox/Rockbox.sh"]}},
        ]
    },
    {
        "label": "TERMINAL",
        "icon": "⬛",
        "color": "green",
        "items": [
            {"label": "Fish Shell",     "cmd": "foot fish",                         "icon": "🐟"},
            {"label": "Tmux Session",   "cmd": "foot tmux new-session -A -s main",  "icon": "📺"},
            {"label": "btop",           "cmd": "foot btop",                         "icon": "📊"},
            {"label": "Ranger Files",   "cmd": "foot ranger",                       "icon": "📁"},
            {"label": "micro Editor",   "cmd": "foot micro",                        "icon": "✏️"},
        ]
    },
    {
        "label": "DISPLAY",
        "icon": "🖥️",
        "color": "blue",
        "items": [
            {"label": "List outputs",   "cmd": "foot display list",                  "icon": "📋"},
            {"label": "Mirror HDMI",    "cmd": "foot display mirror",                "icon": "📺"},
            {"label": "Extend HDMI",    "cmd": "foot display extend",               "icon": "↔️"},
            {"label": "HDMI only",      "cmd": "foot display hdmi-only",            "icon": "🖥️"},
            {"label": "Internal only",  "cmd": "foot display internal",             "icon": "📱"},
            {"label": "Displays off",   "cmd": "display off",                       "icon": "⭕"},
            {"label": "Displays on",    "cmd": "display on",                        "icon": "✅"},
        ]
    },
    {
        "label": "ANDROID",
        "icon": "🤖",
        "color": "green",
        "items": [
            {"label": "ADB shell",      "cmd": "foot adb shell",                     "icon": "📱"},
            {"label": "ADB devices",    "cmd": "foot adb devices",                   "icon": "🔍"},
            {"label": "scrcpy mirror",  "cmd": "scrcpy",                             "icon": "🖥️", "requires": {"commands": ["scrcpy"]}},
            {"label": "fastboot",       "cmd": "foot fastboot devices",              "icon": "⚡"},
            {"label": "androguard",     "cmd": "foot python3 -c 'import androguard; help()'", "icon": "🔬"},
            {"label": "apkleaks",       "cmd": "foot apkleaks",                      "icon": "🔑"},
        ]
    },
    {
        "label": "CAMERA",
        "icon": "📷",
        "color": "peach",
        "items": [
            {"label": "v4l2 list",      "cmd": "foot v4l2-ctl --list-devices",       "icon": "📋"},
            {"label": "fswebcam snap",  "cmd": "foot fswebcam -r 1280x720 ~/snap.jpg && imv ~/snap.jpg", "icon": "📸"},
            {"label": "ffmpeg stream",  "cmd": "foot ffmpeg -f v4l2 -i /dev/video0 -vframes 1 ~/frame.jpg", "icon": "🎬"},
            {"label": "Kinect v1",      "cmd": "foot freenect-glview",               "icon": "🌊"},
            {"label": "Kinect v2",      "cmd": "foot Protonect",                     "icon": "🌊"},
            {"label": "motion detect",  "cmd": "foot sudo motion",                   "icon": "🎯"},
        ]
    },
    {
        "label": "COMMS",
        "icon": "💬",
        "color": "teal",
        "items": [
            {"label": "aerc email",     "cmd": "foot aerc",                          "icon": "📧"},
            {"label": "irssi IRC",      "cmd": "foot irssi",                         "icon": "💬"},
            {"label": "DeltaChat",      "cmd": "foot deltachat",                     "icon": "✉️"},
            {"label": "newsboat RSS",   "cmd": "foot newsboat",                      "icon": "📰"},
        ]
    },
    {
        "label": "POWER",
        "icon": "⚡",
        "color": "yellow",
        "items": [
            {"label": "Power menu",     "cmd": "foot sudo ghost-power",               "icon": "⚡"},
            {"label": "Performance",    "cmd": "sudo ghost-power performance",        "icon": "🚀"},
            {"label": "Balanced",       "cmd": "sudo ghost-power balanced",           "icon": "⚖️"},
            {"label": "Power save",     "cmd": "sudo ghost-power powersave",          "icon": "🔋"},
            {"label": "Max performance","cmd": "sudo ghost-power gaming",             "icon": "🎮"},
            {"label": "SDR mode",       "cmd": "sudo ghost-power sdr",                "icon": "📡"},
            {"label": "Battery status", "cmd": "foot sudo ghost-battery status",      "icon": "🔋"},
            {"label": "Charge limit",   "cmd": "foot sudo ghost-battery limit 80",    "icon": "⚙️"},
        ]
    },
    {
        "label": "THEMES",
        "icon": "🎨",
        "color": "mauve",
        "items": [
            {"label": "Theme menu",     "cmd": "foot ghost-theme",               "icon": "🎨"},
            {"label": "Mocha",          "cmd": "ghost-theme mocha",              "icon": "🌙"},
            {"label": "Cybersec",       "cmd": "ghost-theme cybersec",           "icon": "💚"},
            {"label": "Blueprint",      "cmd": "ghost-theme blueprint",          "icon": "🔵"},
            {"label": "Crimson",        "cmd": "ghost-theme crimson",            "icon": "🔴"},
            {"label": "Aqua",           "cmd": "ghost-theme aqua",               "icon": "🦜"},
            {"label": "Ember",          "cmd": "ghost-theme ember",              "icon": "🐉"},
            {"label": "Cobalt",         "cmd": "ghost-theme cobalt",             "icon": "🎮"},
            {"label": "ghOSt Stealth",  "cmd": "ghost-theme ghost",              "icon": "👻"},
        ]
    },
    {
        "label": "SYSTEM",
        "icon": "⚙️",
        "color": "subtext",
        "items": [
            {"label": "nmtui (WiFi)",   "cmd": "foot nmtui",                         "icon": "📶"},
            {"label": "SSH keys",       "cmd": "foot fish -C 'cat ~/.ssh/id_ed25519.pub | qrencode -t UTF8'", "icon": "🔑"},
            {"label": "Syncthing",      "cmd": "netsurf-gtk http://localhost:8384",   "icon": "🔄"},
            {"label": "Power off",      "cmd": "sudo poweroff",                      "icon": "⭕"},
            {"label": "Reboot",         "cmd": "sudo reboot",                        "icon": "🔁"},
        ]
    },
]

# =============================================================================
# LAUNCHER CLASS
# =============================================================================
class GhOStLauncher:
    def __init__(self):
        sdl2.SDL_Init(sdl2.SDL_INIT_VIDEO | sdl2.SDL_INIT_JOYSTICK |
                      sdl2.SDL_INIT_GAMECONTROLLER | sdl2.SDL_INIT_AUDIO)
        ttf.TTF_Init()

        self.window = sdl2.SDL_CreateWindow(
            b"ghOSt",
            sdl2.SDL_WINDOWPOS_CENTERED, sdl2.SDL_WINDOWPOS_CENTERED,
            SCREEN_W, SCREEN_H,
            sdl2.SDL_WINDOW_SHOWN | sdl2.SDL_WINDOW_FULLSCREEN_DESKTOP
        )
        self.renderer = sdl2.SDL_CreateRenderer(
            self.window, -1,
            sdl2.SDL_RENDERER_ACCELERATED | sdl2.SDL_RENDERER_PRESENTVSYNC
        )
        self.screen_w, self.screen_h = self._renderer_size()

        # Try to load a good font, fall back to built-in
        self.font_large = self._load_font(24)
        self.font_medium = self._load_font(18)
        self.font_small = self._load_font(13)

        self.menu = self._build_menu()
        if not self.menu:
            self.menu = [{
                "label": "TERMINAL",
                "icon": "⬛",
                "color": "green",
                "items": [{"label": "Fish Shell", "cmd": "foot fish", "icon": "🐟"}],
            }]

        self.cat_idx = self._default_category_index()  # Selected category
        self.item_idx = 0         # Selected item in category
        self.mode = "categories"  # "categories" or "items"
        self.status_msg = ""
        self.status_time = 0
        self.mouse_pos = (0, 0)
        self.hovered_category = None
        self.hovered_item = None
        self.tooltips_enabled = True

        # Battery & status
        self.battery_pct = self._read_battery()
        self.battery_timer = 0

        self.running = True

        # Wallpaper texture (SHODAN)
        self.wallpaper = self._load_wallpaper()

    def _renderer_size(self):
        width = ctypes.c_int(SCREEN_W)
        height = ctypes.c_int(SCREEN_H)
        try:
            sdl2.SDL_GetRendererOutputSize(
                self.renderer,
                ctypes.byref(width),
                ctypes.byref(height),
            )
        except Exception:
            pass
        return max(width.value, SCREEN_W), max(height.value, SCREEN_H)

    def _layout(self):
        sidebar_w = max(220, min(280, self.screen_w // 4))
        status_h = 30
        footer_h = 28
        header_h = 48
        category_row_h = max(
            34,
            (self.screen_h - status_h - footer_h - 8) // max(1, len(self.menu)),
        )
        return {
            "sidebar_w": sidebar_w,
            "panel_x": sidebar_w + 10,
            "panel_w": self.screen_w - sidebar_w - 16,
            "status_h": status_h,
            "footer_h": footer_h,
            "header_h": header_h,
            "category_row_h": category_row_h,
        }

    def _item_row_h(self):
        layout = self._layout()
        items = self.menu[self.cat_idx]["items"]
        available_h = self.screen_h - layout["status_h"] - layout["footer_h"] - layout["header_h"] - 26
        return max(48, min(64, available_h // max(1, len(items))))

    def _category_rect(self, index):
        layout = self._layout()
        y = layout["status_h"] + index * layout["category_row_h"]
        return (0, y, layout["sidebar_w"], layout["category_row_h"])

    def _item_rect(self, index):
        layout = self._layout()
        row_h = self._item_row_h()
        y = layout["status_h"] + layout["header_h"] + 8 + index * row_h
        return (layout["panel_x"], y, layout["panel_w"] - 6, row_h - 4)

    def _tooltip_for_current_target(self):
        if self.hovered_item is not None:
            item = self.menu[self.cat_idx]["items"][self.hovered_item]
            return item.get("tooltip") or item["cmd"]
        if self.hovered_category is not None:
            category = self.menu[self.hovered_category]
            return CATEGORY_HINTS.get(category["label"], category["label"])
        if self.mode == "items":
            item = self.menu[self.cat_idx]["items"][self.item_idx]
            return item.get("tooltip") or item["cmd"]
        return CATEGORY_HINTS.get(self.menu[self.cat_idx]["label"], "")

    def _update_hover_state(self):
        mx, my = self.mouse_pos
        self.hovered_category = None
        self.hovered_item = None

        for index in range(len(self.menu)):
            x, y, w, h = self._category_rect(index)
            if x <= mx < x + w and y <= my < y + h:
                self.hovered_category = index
                return

        for index in range(len(self.menu[self.cat_idx]["items"])):
            x, y, w, h = self._item_rect(index)
            if x <= mx < x + w and y <= my < y + h:
                self.hovered_item = index
                return

    def _item_available(self, item):
        """Keep optional UI entries honest by hiding tools that were not built."""
        requirements = item.get("requires", {})
        for path in requirements.get("paths", []):
            if not Path(path).exists():
                return False
        for command in requirements.get("commands", []):
            if shutil.which(command) is None:
                return False
        return True

    def _build_menu(self):
        """Drop categories and entries for optional components that are absent."""
        filtered_menu = []
        for category in MENU_TEMPLATE:
            items = [item for item in category["items"] if self._item_available(item)]
            if not items:
                continue
            filtered_menu.append({
                "label": category["label"],
                "icon": category["icon"],
                "color": category["color"],
                "items": items,
            })
        return filtered_menu

    def _default_category_index(self):
        """Open on the security workflow first instead of on general-purpose tools."""
        preferred_labels = ["SIGNAL INT", "RECON", "WIRELESS", "TOOLS", "PRIVACY", "TERMINAL"]
        for label in preferred_labels:
            for index, category in enumerate(self.menu):
                if category["label"] == label:
                    return index
        return 0

    def _load_wallpaper(self):
        """Load wallpaper PNG as SDL texture. Regenerate if missing."""
        WALL_PATH = "/opt/ghost/launcher/wallpaper.png"
        GEN_PATH  = "/opt/ghost/themes/generate-wallpaper.py"
        import os as _os
        # Generate if missing
        if not _os.path.exists(WALL_PATH) and _os.path.exists(GEN_PATH):
            try:
                import subprocess as _sp
                _sp.run(["python3", GEN_PATH, WALL_PATH, "cybersec"],
                        capture_output=True, timeout=20)
            except Exception:
                pass
        if not _os.path.exists(WALL_PATH):
            return None
        try:
            img.IMG_Init(img.IMG_INIT_PNG)
            surface = img.IMG_Load(WALL_PATH.encode())
            if not surface:
                return None
            texture = sdl2.SDL_CreateTextureFromSurface(self.renderer, surface)
            sdl2.SDL_FreeSurface(surface)
            # Semi-transparent overlay: multiply alpha for menu readability
            sdl2.SDL_SetTextureAlphaMod(texture, 210)
            return texture
        except Exception:
            return None

    def _load_font(self, size):
        fonts = [
            "/usr/share/fonts/X11/misc/ter-x14b.pcf.gz",
            "/usr/share/fonts/truetype/terminus/TerminusTTF-Bold.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationMono-Bold.ttf",
        ]
        for f in fonts:
            if Path(f).exists():
                font = ttf.TTF_OpenFont(f.encode(), size)
                if font:
                    return font
        return None

    def _read_battery(self):
        paths = [
            "/sys/class/power_supply/axp20x-battery/capacity",
            "/sys/class/power_supply/BAT0/capacity",
        ]
        for p in paths:
            try:
                return int(Path(p).read_text().strip())
            except:
                pass
        return -1

    def _color(self, name):
        c = COLORS.get(name, COLORS["text"])
        return sdl2.SDL_Color(c[0], c[1], c[2], c[3])

    def _set_color(self, name):
        c = COLORS.get(name, COLORS["text"])
        sdl2.SDL_SetRenderDrawColor(self.renderer, c[0], c[1], c[2], c[3])

    def _render_text(self, text, font, color_name, x, y):
        if not font:
            return
        surface = ttf.TTF_RenderUTF8_Blended(
            font, text.encode('utf-8', errors='replace'),
            self._color(color_name)
        )
        if not surface:
            return
        texture = sdl2.SDL_CreateTextureFromSurface(self.renderer, surface)
        sdl2.SDL_FreeSurface(surface)
        if not texture:
            return
        w, h = ctypes.c_int(), ctypes.c_int()
        sdl2.SDL_QueryTexture(texture, None, None, ctypes.byref(w), ctypes.byref(h))
        dst = sdl2.SDL_Rect(x, y, w.value, h.value)
        sdl2.SDL_RenderCopy(self.renderer, texture, None, dst)
        sdl2.SDL_DestroyTexture(texture)
        return w.value, h.value

    def _fill_rect(self, x, y, w, h, color_name, alpha=255):
        c = COLORS.get(color_name, COLORS["surface0"])
        sdl2.SDL_SetRenderDrawBlendMode(self.renderer, sdl2.SDL_BLENDMODE_BLEND)
        sdl2.SDL_SetRenderDrawColor(self.renderer, c[0], c[1], c[2], alpha)
        rect = sdl2.SDL_Rect(x, y, w, h)
        sdl2.SDL_RenderFillRect(self.renderer, rect)

    def draw_status_bar(self):
        """Top status bar: hostname, battery, time"""
        layout = self._layout()
        self._fill_rect(0, 0, self.screen_w, layout["status_h"], "surface0")

        import datetime
        now = datetime.datetime.now().strftime("%H:%M")

        # Left: hostname
        self._render_text(" ghOSt uConsole", self.font_small, "blue", 6, 7)

        # Center: status message
        if self.status_msg and time.time() - self.status_time < 3:
            self._render_text(self.status_msg, self.font_small, "green",
                              self.screen_w // 2 - 80, 7)

        # Right: battery + time
        bat_str = f"🔋{self.battery_pct}%  {now} " if self.battery_pct >= 0 else f" {now} "
        bat_color = "green" if self.battery_pct > 30 else "yellow" if self.battery_pct > 15 else "red"
        self._render_text(bat_str, self.font_small, bat_color,
                          self.screen_w - len(bat_str) * 8 - 6, 7)

    def draw_categories(self):
        """Left sidebar: category list"""
        layout = self._layout()
        sidebar_w = layout["sidebar_w"]
        row_h = layout["category_row_h"]

        # Background
        self._fill_rect(0, layout["status_h"], sidebar_w,
                        self.screen_h - layout["status_h"] - layout["footer_h"],
                        "surface0")

        for i, cat in enumerate(self.menu):
            y = layout["status_h"] + i * row_h
            is_selected = (i == self.cat_idx)
            is_hovered = (i == self.hovered_category)

            if is_selected or is_hovered:
                self._fill_rect(0, y, sidebar_w, row_h, "surface1")
                # Left accent bar
                self._fill_rect(0, y, 4, row_h, cat.get("color", "blue"))

            color = cat.get("color", "blue") if (is_selected or is_hovered) else "subtext"
            label = f" {cat['icon']} {cat['label']}"
            self._render_text(label, self.font_small, color, 10, y + max(8, row_h // 3))

    def draw_items(self):
        """Right panel: items in selected category"""
        cat = self.menu[self.cat_idx]
        layout = self._layout()
        panel_x = layout["panel_x"]
        panel_w = layout["panel_w"]
        row_h = self._item_row_h()

        # Category header
        self._fill_rect(panel_x, layout["status_h"], panel_w, layout["header_h"], "surface1")
        header = f" {cat['icon']}  {cat['label']}"
        self._render_text(header, self.font_large,
                          cat.get("color", "blue"), panel_x + 12, layout["status_h"] + 10)

        # Items
        for i, item in enumerate(cat["items"]):
            y = layout["status_h"] + layout["header_h"] + 8 + i * row_h
            is_selected = (i == self.item_idx) and self.mode == "items"
            is_hovered = (i == self.hovered_item)

            if is_selected or is_hovered:
                self._fill_rect(panel_x, y - 2, panel_w - 4, row_h - 4,
                                "surface1")
                self._fill_rect(panel_x, y - 2, 4, row_h - 4,
                                cat.get("color", "blue"))

            label_color = "text" if (is_selected or is_hovered) else "subtext"
            icon_color = cat.get("color", "blue") if (is_selected or is_hovered) else "overlay"

            self._render_text(f" {item['icon']}", self.font_medium,
                              icon_color, panel_x + 10, y + 6)
            self._render_text(item["label"], self.font_medium,
                              label_color, panel_x + 42, y + 6)

            # Show command hint if selected
            if is_selected or is_hovered:
                cmd_preview = item["cmd"][:80] + "..." if len(item["cmd"]) > 80 else item["cmd"]
                self._render_text(f"  {cmd_preview}", self.font_small,
                                  "overlay", panel_x + 12, y + max(26, row_h // 2))

    def draw_tooltip(self):
        tooltip = self._tooltip_for_current_target()
        if not tooltip or not self.tooltips_enabled:
            return

        layout = self._layout()
        x = layout["panel_x"]
        y = self.screen_h - layout["footer_h"] - 34
        w = layout["panel_w"]
        self._fill_rect(x, y, w, 28, "surface0", alpha=230)
        if len(tooltip) > 120:
            tooltip = tooltip[:117] + "..."
        self._render_text(f" {tooltip}", self.font_small, "subtext", x + 8, y + 7)

    def draw_button_hints(self):
        """Bottom bar: button hints"""
        layout = self._layout()
        self._fill_rect(0, self.screen_h - layout["footer_h"], self.screen_w, layout["footer_h"], "surface0")

        hints = " Mouse/Trackball hover: tooltip  Arrow keys: move  Enter: launch  Esc: back  T: terminal  Ctrl+G: stealth"
        self._render_text(hints, self.font_small, "overlay", 6, self.screen_h - layout["footer_h"] + 7)

    def draw(self):
        # Clear with bg color
        c = COLORS["bg"]
        sdl2.SDL_SetRenderDrawColor(self.renderer, c[0], c[1], c[2], 255)
        sdl2.SDL_RenderClear(self.renderer)

        # Blit wallpaper
        if self.wallpaper:
            dst = sdl2.SDL_Rect(0, 0, self.screen_w, self.screen_h)
            sdl2.SDL_RenderCopy(self.renderer, self.wallpaper, None, dst)
            # Dark overlay so UI text stays readable
            sdl2.SDL_SetRenderDrawBlendMode(self.renderer, sdl2.SDL_BLENDMODE_BLEND)
            sdl2.SDL_SetRenderDrawColor(self.renderer, 0, 0, 0, 140)
            sdl2.SDL_RenderFillRect(self.renderer, dst)
            sdl2.SDL_SetRenderDrawBlendMode(self.renderer, sdl2.SDL_BLENDMODE_NONE)

        self.draw_status_bar()
        self.draw_categories()
        self.draw_items()
        self.draw_tooltip()
        self.draw_button_hints()

        sdl2.SDL_RenderPresent(self.renderer)

    def launch(self, cmd):
        """Launch application"""
        self.status_msg = f"Launching..."
        self.status_time = time.time()
        threading.Thread(
            target=subprocess.run,
            args=(["/bin/fish", "-c", cmd],),
            kwargs={"env": {**os.environ}},
            daemon=True
        ).start()

    def enter_stealth(self):
        """Activate stealth mode via stealthd"""
        subprocess.Popen(["python3", "/opt/ghost/stealthd/stealthd.py", "--activate"])

    def handle_button(self, btn, pressed):
        """Handle gamepad button events"""
        if not pressed:
            return

        # Navigation
        if btn in (sdl2.SDL_CONTROLLER_BUTTON_DPAD_UP,):
            if self.mode == "categories":
                self.cat_idx = (self.cat_idx - 1) % len(self.menu)
                self.item_idx = 0
            else:
                items = self.menu[self.cat_idx]["items"]
                self.item_idx = (self.item_idx - 1) % len(items)

        elif btn in (sdl2.SDL_CONTROLLER_BUTTON_DPAD_DOWN,):
            if self.mode == "categories":
                self.cat_idx = (self.cat_idx + 1) % len(self.menu)
                self.item_idx = 0
            else:
                items = self.menu[self.cat_idx]["items"]
                self.item_idx = (self.item_idx + 1) % len(items)

        elif btn in (sdl2.SDL_CONTROLLER_BUTTON_DPAD_RIGHT,
                     sdl2.SDL_CONTROLLER_BUTTON_A):
            if self.mode == "categories":
                self.mode = "items"
                self.item_idx = 0
            else:
                # Launch selected item
                item = self.menu[self.cat_idx]["items"][self.item_idx]
                self.launch(item["cmd"])

        elif btn in (sdl2.SDL_CONTROLLER_BUTTON_DPAD_LEFT,
                     sdl2.SDL_CONTROLLER_BUTTON_B):
            self.mode = "categories"

        elif btn == sdl2.SDL_CONTROLLER_BUTTON_START:
            # Direct terminal launch
            self.launch("foot fish")

    def handle_events(self):
        event = sdl2.SDL_Event()
        while sdl2.SDL_PollEvent(ctypes.byref(event)):
            if event.type == sdl2.SDL_QUIT:
                self.running = False

            elif event.type == sdl2.SDL_CONTROLLERBUTTONDOWN:
                self.handle_button(event.cbutton.button, True)

            elif event.type == sdl2.SDL_CONTROLLERBUTTONUP:
                self.handle_button(event.cbutton.button, False)

            elif event.type == sdl2.SDL_KEYDOWN:
                # Keyboard support (USB/BT keyboard)
                k = event.key.keysym.sym
                mods = sdl2.SDL_GetModState()
                if k == sdl2.SDLK_UP:
                    self.handle_button(sdl2.SDL_CONTROLLER_BUTTON_DPAD_UP, True)
                elif k == sdl2.SDLK_DOWN:
                    self.handle_button(sdl2.SDL_CONTROLLER_BUTTON_DPAD_DOWN, True)
                elif k == sdl2.SDLK_RIGHT:
                    self.handle_button(sdl2.SDL_CONTROLLER_BUTTON_DPAD_RIGHT, True)
                elif k == sdl2.SDLK_LEFT:
                    self.handle_button(sdl2.SDL_CONTROLLER_BUTTON_DPAD_LEFT, True)
                elif k in (sdl2.SDLK_RETURN, sdl2.SDLK_KP_ENTER):
                    self.handle_button(sdl2.SDL_CONTROLLER_BUTTON_A, True)
                elif k == sdl2.SDLK_ESCAPE:
                    self.handle_button(sdl2.SDL_CONTROLLER_BUTTON_B, True)
                elif k == sdl2.SDLK_t:
                    self.launch("foot fish")
                elif k == sdl2.SDLK_g and mods & sdl2.KMOD_CTRL:
                    self.enter_stealth()

            elif event.type == sdl2.SDL_MOUSEMOTION:
                self.mouse_pos = (event.motion.x, event.motion.y)
                self._update_hover_state()

            elif event.type == sdl2.SDL_MOUSEBUTTONDOWN:
                self.mouse_pos = (event.button.x, event.button.y)
                self._update_hover_state()
                if event.button.button == sdl2.SDL_BUTTON_LEFT:
                    if self.hovered_category is not None:
                        self.cat_idx = self.hovered_category
                        self.item_idx = 0
                        self.mode = "categories"
                    elif self.hovered_item is not None:
                        if self.mode == "items" and self.item_idx == self.hovered_item:
                            item = self.menu[self.cat_idx]["items"][self.item_idx]
                            self.launch(item["cmd"])
                        else:
                            self.item_idx = self.hovered_item
                            self.mode = "items"
                elif event.button.button == sdl2.SDL_BUTTON_RIGHT:
                    self.mode = "categories"

    def run(self):
        # Open first gamepad
        if sdl2.SDL_NumJoysticks() > 0:
            controller = sdl2.SDL_GameControllerOpen(0)

        clock_start = sdl2.SDL_GetTicks()

        while self.running:
            self.handle_events()

            # Update battery every 60s
            self.battery_timer += 1
            if self.battery_timer >= FPS * 60:
                self.battery_pct = self._read_battery()
                self.battery_timer = 0

            self.draw()

            # Cap at FPS
            elapsed = sdl2.SDL_GetTicks() - clock_start
            delay = max(0, (1000 // FPS) - elapsed)
            sdl2.SDL_Delay(delay)
            clock_start = sdl2.SDL_GetTicks()

        self.cleanup()

    def cleanup(self):
        if self.font_large: ttf.TTF_CloseFont(self.font_large)
        if self.font_medium: ttf.TTF_CloseFont(self.font_medium)
        if self.font_small: ttf.TTF_CloseFont(self.font_small)
        sdl2.SDL_DestroyRenderer(self.renderer)
        sdl2.SDL_DestroyWindow(self.window)
        ttf.TTF_Quit()
        sdl2.SDL_Quit()


if __name__ == "__main__":
    launcher = GhOStLauncher()
    _launcher_instance = launcher  # expose for SIGUSR1 handler
    signal.signal(signal.SIGTERM, lambda *_: setattr(launcher, 'running', False))
    launcher.run()

# Theme reload signal handler (called by ghost-theme after applying)
import signal as _signal
import json as _json
from pathlib import Path as _Path

_launcher_instance = None  # Set by GhOStLauncher.__init__

def _reload_theme(signum, frame):
    """Called via SIGUSR1 when ghost-theme applies a new theme"""
    theme_file = _Path("/opt/ghost/launcher/theme.json")
    if theme_file.exists():
        try:
            theme = _json.loads(theme_file.read_text())
            global COLORS
            COLORS = {k: tuple(v[:3]) for k, v in theme.items()
                      if isinstance(v, list) and len(v) >= 3}
        except Exception:
            pass
    # Reload wallpaper (theme change regenerates it)
    global _launcher_instance
    if _launcher_instance:
        try:
            if _launcher_instance.wallpaper:
                import sdl2 as _sdl2
                _sdl2.SDL_DestroyTexture(_launcher_instance.wallpaper)
            _launcher_instance.wallpaper = _launcher_instance._load_wallpaper()
        except Exception:
            pass

_signal.signal(_signal.SIGUSR1, _reload_theme)
