# Simple Scroll Reverser

A free, open-source macOS menu-bar utility that reverses scrolling independently for a **mouse** (including Magic Mouse when it can be detected) and a **trackpad**. Keep System Settings “natural” scrolling for the trackpad while using classic wheel scrolling on a mouse — or the other way around.

Anyone can clone this repository, build the app, and use it. There is no paid license, no account, and no sandbox requirement.

This project is an original implementation. It is **not** affiliated with [Pilotmoon Scroll Reverser](https://pilotmoon.com/scrollreverser/).

**Bundle ID:** `com.ajju2004srivatsan.simplescrollreverser`  
**Requirements:** macOS 13.5 or later (Ventura), Intel or Apple silicon  
**License:** [MIT](LICENSE)

## Install (build it yourself)

1. Clone this repo on a Mac.
2. Open `SimpleScrollReverser.xcodeproj` in Xcode 15 or later.
3. Select the **SimpleScrollReverser** scheme.
4. Optionally set your **Team** under *Signing & Capabilities* if you want a stable Apple Development signature (recommended so Accessibility permission survives rebuilds). Local ad-hoc signing (`-`) also works for a first run.
5. Choose **Product → Run** (⌘R), or **Product → Archive** if you want a standalone `.app`.

The built app is an agent (no Dock icon). Look for the up/down arrows in the menu bar.

Drag `Simple Scroll Reverser.app` to `/Applications` if you want Start at Login to be reliable.

The app is **not sandboxed**. That is required for a CGEvent tap that rewrites scroll deltas after Accessibility is granted.

## Grant permissions

Scrolling cannot be inverted until macOS allows this process to observe HID events.

1. Open the app (the preferences window appears on first launch).
2. If you see a permission banner, click **Open Accessibility Settings**.
3. Enable **Simple Scroll Reverser** under **System Settings → Privacy & Security → Accessibility**.
4. If scrolling still does not reverse, also enable it under **Privacy & Security → Input Monitoring**.
5. Return to the app and click **Check Permissions**, then make sure **Enable Scroll Reverser** is on.

If the toggle does nothing after a rebuild, remove the app from the Accessibility list with “−”, add it again with “+”, and relaunch.

## Recommended settings

A common setup:

| Place | Setting |
| --- | --- |
| System Settings → Trackpad | **Natural scrolling** on |
| Simple Scroll Reverser | **Reverse mouse** on |
| Simple Scroll Reverser | **Reverse trackpad** off |
| Simple Scroll Reverser | **Reverse vertical** on |

That keeps two-finger trackpad gestures matching the rest of macOS, while a mouse wheel feels “classic” (content moves down when you roll the wheel down). Reverse horizontal independently if you use tilt wheels.

Right-click is not required: the master enable switch is the first item in the menu bar menu.

Re-launching the app while it is already running focuses the preferences window instead of starting a second copy.

## Wheel step size

If you use a clicky (non-continuous) scroll wheel, the **Wheel step size** slider can replace macOS wheel acceleration with a fixed number of lines per click. Leave it on **System default** unless you want that behavior.

## Uninstall

1. Quit from the menu bar item.
2. Move `Simple Scroll Reverser.app` to the Trash.
3. Optional: delete preferences  
   `~/Library/Preferences/com.ajju2004srivatsan.simplescrollreverser.plist`  
   or run `defaults delete com.ajju2004srivatsan.simplescrollreverser`.
4. Optional: remove it from **System Settings → General → Login Items & Extensions** and from the Accessibility / Input Monitoring lists.

Nothing else is installed.

## Signing and notarization (optional)

For personal use, **Xcode → Run** is enough. Gatekeeper may require a right-click → **Open** the first time if you copy an unsigned build to another Mac.

For a build you share with others:

1. Select your Developer ID team in Signing & Capabilities.
2. Enable **Hardened Runtime** on the target.
3. Archive, then notarize with `notarytool` (or Organizer).

Notarization is **not** required to use the app on the Mac that built it.

## How it works

The app installs a `CGEvent` tap for scroll-wheel events and inverts the line, pixel, and fixed-point delta fields in place (so apps such as Safari still see a normal scroll event). Device type is decided from:

1. Recent HID activity (IOKit) so a Magic Mouse is treated as a mouse, not a trackpad.
2. A fallback on public CGEvent fields: discrete line scrolling is a mouse wheel; continuous scrolling with a gesture/momentum phase is a trackpad; continuous scrolling with no phase is treated as a mouse (Magic Mouse / other smooth wheels).

Some older or unusual trackpads report as mice. That is a known macOS limitation.

Start at login uses `SMAppService` (macOS 13+ login item API).

## Project layout

```
SimpleScrollReverser.xcodeproj   Xcode project (repo root)
SimpleScrollReverser/            Swift + SwiftUI sources, Info.plist, assets
Scripts/generate_icon.py         Regenerates the original app icon
LICENSE                          MIT
```

## Contributing

Issues and pull requests are welcome. Keep the UI small, do not add auto-update or copy branding/assets from other apps, and keep the project free for anyone to clone and run.
