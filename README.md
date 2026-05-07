# 🐱 Bongo Cat Claimer

An AutoHotkey v2 script for [Bongo Cat](https://store.steampowered.com/app/1820530/Bongo_Cat/) on Steam that automatically claims your chests and generates points while you're away — or just not paying attention.

---

## What it does

Bongo Cat gives you **1 point per keystroke or mouse click**, and every 30 minutes two chests become available to claim (1,000 points each — 2,000 total for both). This script handles all of that for you:

- **Auto Chest Claimer** — automatically clicks both chests the moment they're ready, every ~30.5 minutes
- **Realistic Typing** — generates keystrokes in a natural burst-pause rhythm so the computer doesn't fall asleep and points keep accumulating
- **Spam** — sends keystrokes as fast as possible when you're not using the computer; great for building up points overnight

---

## Requirements

- [AutoHotkey v2](https://www.autohotkey.com/) (v2.0 or later)
- [Bongo Cat](https://store.steampowered.com/app/1820530/Bongo_Cat/) installed and running via Steam

> ⚠️ **Do NOT run Bongo Cat as Administrator.** The script doesn't play well with it in that mode. Run it normally.

---

## Installation

1. Install AutoHotkey v2 from [autohotkey.com](https://www.autohotkey.com/)
2. Download `BongoCat_Claimer.ahk` from this repo
3. Place it anywhere on your computer
4. Double-click to run it

A `BongoCat.ini` config file will be created automatically in the same folder the first time you run the script.

---

## Setup

F10 behaves differently depending on whether you've run it before.

### First time (no `BongoCat.ini` yet)

1. Make sure Bongo Cat is running and **both chests are visible** (the `1000` counters are shown)
2. Press **F10** to enter setup mode
3. Click somewhere on the **upper body or forehead of your cat** — roughly the center horizontally
4. The script calculates both chest positions using a fixed offset (82px by default), **claims both chests immediately**, and starts the 30.5-minute timer

### Moving the cat (subsequent F10 presses)

If you drag your cat to a new position, press **F10** and click the cat center again. This updates the coordinates only — **the claim timers are not reset**. You don't need to have chests available to do this.

The only way to reset the timers is **F12** (Force Claim).

> ℹ️ If the script misses the chests (slightly off on your screen), adjust the **Chest offset from center** value in Settings (F5) without re-running setup.

---

## Hotkeys

All hotkeys except F5 are fully rebindable from the Settings screen.

| Key | Action |
|-----|--------|
| **F5** | Open Settings *(fixed, cannot be rebound)* |
| **F6** | Toggle Realistic Typing on/off |
| **F7** | Quit the script |
| **F8** | Toggle Spam on/off |
| **F9** | Toggle the overlay timer GUI |
| **F10** | Setup — first run claims chests; subsequent runs update position only (timers unchanged) |
| **F12** | Force claim both chests right now |

---

## Features

### Auto Chest Claimer
Checks every second and automatically clicks both chests when the timer is up. The script moves your mouse to each chest, clicks it, and immediately returns your cursor to where it was — the whole thing takes under 200ms. Focus is restored to whatever window you were using.

The claim interval defaults to **30.5 minutes** (slightly over 30 to account for any timer drift in Bongo Cat). Both chests have independent timers with a ~1 second offset between them.

### Overlay GUI (F9)
Two small dark overlay windows appear just above each chest showing a live countdown timer. They turn green and show **READY** when a chest is available. Toggle them with F9.

### Realistic Typing (F6)
Generates keystrokes in a human-like pattern: a random burst of N keystrokes, a short pause, repeat. Automatically pauses when it detects you're actively using the mouse or keyboard, and resumes when you stop.

Good for: keeping the computer awake and accumulating points passively while you're at your desk but not actively typing.

### Spam (F8)
Sends keystrokes as fast as possible (~11 keystrokes every 2ms). Generates a large number of points quickly.

> ⚠️ **Heads up:** Spam is CPU-intensive and will noticeably load your system. It's not recommended for use while actively working. Also, keyboard shortcuts and key combinations may not work properly while spam is running. Use it when you're away from the computer.

> ⚠️ **Also note:** If a fullscreen game is running, the script may pull focus away from it. Avoid running this while actively gaming.

---

## Settings (F5)

Press F5 to open the settings window. Changes apply immediately when you click OK and are saved to `BongoCat.ini`.

### Claimer
| Setting | Default | Description |
|---------|---------|-------------|
| Claim interval (minutes) | `30.5` | How long to wait between auto-claims |
| Clicks per chest | `3` | How many times to click each chest (more = more reliable) |
| Chest offset from center (px) | `82` | Horizontal distance in pixels from the cat's center to each chest. Increase or decrease this if the script is missing the chests on your screen. |

### Realistic Typing
| Setting | Default | Description |
|---------|---------|-------------|
| Burst min | `3` | Minimum keystrokes per burst |
| Burst max | `8` | Maximum keystrokes per burst |
| Fast delay min (ms) | `60` | Minimum delay between keystrokes in a burst |
| Fast delay max (ms) | `140` | Maximum delay between keystrokes in a burst |
| Pause min (ms) | `300` | Minimum pause between bursts |
| Pause max (ms) | `900` | Maximum pause between bursts |
| Idle timeout (ms) | `1000` | How long after your last input before typing resumes |

### Spam
| Setting | Default | Description |
|---------|---------|-------------|
| Spam interval (ms) | `1` | Delay between keystroke batches |

### Hotkeys
Click any hotkey button, then press the key you want to assign. Modifier keys are supported — hold Ctrl, Alt, Shift, or Win while pressing the key to include them (e.g. Ctrl+F6).

---

## Mouse Hijacking

When a chest is claimed, the script briefly takes control of your mouse (~200ms) to move it to the chest and click. During this time your physical mouse movement is frozen. This is unavoidable — Bongo Cat is a DirectX overlay and can't receive simulated clicks any other way.

The script is designed to minimise disruption: your cursor is returned to exactly where it was, and focus is restored to your active window immediately after.

---

## Notes

- The script generates no exploits and uses no external tools — it just simulates mouse clicks and keystrokes
- Detection status is believed to be **Undetected**
- Settings survive script restarts — timestamps and the cat's position are saved in `BongoCat.ini`
- If you move your cat widget on screen, press **F10** and click the cat once to update the position
- UI elements on websites or applications located behind your cat widget may occasionally receive clicks — this is a Windows responsiveness side effect, not a script bug

---

## Files

```
BongoCat_Claimer.ahk   ← the script
BongoCat.ini           ← auto-generated config (do not delete unless resetting)
```

---

## License

Do whatever you want with it.