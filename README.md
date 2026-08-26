# OmaVibes: Type with Cozy Sound
OmaVibes gives you cozy typing sound effects with over 40+ sounds, gamified typing stats with ranks, detailed analytics, random playback, and volume control for the Omarchy bar.

---

<img width="1672" height="941" alt="preview" src="https://github.com/user-attachments/assets/111b2184-2798-4d72-9fbb-856a07cc3771" />


https://github.com/user-attachments/assets/1af267b1-29c0-4423-8530-0c5b8d533819


<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/83c98e4f-1c3f-4a95-ab12-eb784362f163" />
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/d51305f9-45ac-4624-a16e-c33c190d1334" />
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/3b836e01-9d52-4ed9-8071-9ede513d5c49" />
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/936556ba-b6a0-4aa0-b010-20ef3193cce9" />
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/f3522a35-2158-40ef-a1a7-570f9ba1a2cd" />

`Note: Enable sound in the above preview video`

---
> I didn't originally plan on releasing this.
>
> I created OmaVibes because I wanted cozy typing sounds while typing, but I couldn't afford a mechanical keyboard sound setup. So I decided to build my own solution.
>
> OmaVibes originally started with a Walker-based implementation, and eventually evolved into an Omarchy plugin with a proper bar interface, soundpack browser, search, random playback, per-pack volume control, persistent settings, and built-in typing stats and analytics.
>
> Hopefully you enjoy it.


## What is OmaVibes?
OmaVibes is an Omarchy bar widget that plays cozy typing sound effects whenever you type.

It comes with over 40+ sounds across the bundled soundpacks, along with search, random playback, volume control, a typing profile, gamified ranks, achievements, and detailed typing analytics.

OmaVibes uses **wayvibes** as its typing sound runtime. It listens for keyboard input and plays the selected sound effects while you type. The required runtime is bundled with OmaVibes, so no separate `wayvibes` installation is required.

---
## Features

* **Omarchy bar integration** — Open OmaVibes directly from the top bar.
* **40+ typing sounds** — A collection of cozy typing sound effects across the bundled soundpacks.
* **Soundpack browser** — Browse the available soundpacks from one panel.
* **Search** — Filter soundpacks instantly by name.
* **One-click playback** — Select a soundpack to start playing it immediately.
* **Random playback** — Pick a random soundpack from the available collection.
* **Turn Off** — Stop the currently playing typing sounds.
* **Volume control** — Adjust the volume from 1 to 10.
* **Per-pack volume** — Each soundpack remembers its own volume setting.
* **Persistent settings** — Soundpack and volume settings are preserved across shell restarts.
* **Profile** — See your lifetime typing progress, current rank, progress toward the next rank, personal records, and completed achievements.
* **Gamified ranks** — Lifetime words typed determine your rank, with increasingly difficult tiers to climb.
* **Achievements** — Unlock typing milestones based on lifetime words, key presses, typing days, and streaks.
* **Detailed analytics** — Explore daily, weekly, monthly, and lifetime typing statistics.
* **Key analytics** — See your most-used keys, key frequency, keyboard usage, and other typing statistics.
* **Theme-aware interface** — Uses Omarchy/Quickshell styling and the active bar font and theme colors.
* **Local analytics** — Typing statistics stay on the device, and the actual text you type is never stored.
* **Bundled runtime** — Includes the `wayvibes` executable and bundled soundpacks, so a separate `wayvibes` installation is not required.

## Requirements

* **Omarchy 4 (Quattro)**
* A working Quickshell-based Omarchy shell
* Keyboard input access for `wayvibes`

### Keyboard Input Access

Depending on your system configuration, `wayvibes` may require your user to be part of the `input` group:

```bash
sudo usermod -aG input $USER
```

Log out and back in after changing the group.

## Installation

### From the Omarchy Plugin Marketplace

Once OmaVibes is published:

```bash
omarchy plugin add mshareef-git.omavibes --enable
```

### From GitHub

Clone the repository into the Omarchy plugin directory:

```bash
git clone https://github.com/mshareef-git/omavibes.git \
  ~/.config/omarchy/plugins/omavibes
```

Validate the plugin:

```bash
omarchy plugin validate ~/.config/omarchy/plugins/omavibes
```

Enable the plugin on the right side of the bar:

```bash
omarchy plugin enable mshareef-git.omavibes right
```

Restart the shell if necessary:

```bash
omarchy restart shell
```

## Usage

Click the OmaVibes keyboard icon in the Omarchy top bar.

### Keyboard input

Use the settings cog in the top-right corner of the panel to choose which
keyboard OmaVibes listens to. It lists every keyboard-capable input device,
including virtual keyboards. OmaVibes saves a stable `/dev/input/by-id` path
when one is available, then uses that selection the next time playback starts.

### Search

Use the search field to filter the available soundpacks by name.

### Play a Soundpack

Click any soundpack in the list to start playing it.

The currently selected soundpack is highlighted and marked with a check.

### Profile

Open **Profile** to see your typing progression.

The profile includes:

* Current rank
* Progress toward the next rank
* Lifetime words
* Lifetime typing time
* Lifetime key presses
* Active days
* Longest streak
* Personal records
* Completed achievements

Your rank is based on lifetime words typed and becomes progressively harder as you move upward.

### Stats

Open **Stats** for detailed typing analytics.

Stats include:

* Day / Week / Month views
* Words typed
* Typing time
* Typing vs idle time
* Typing activity
* Words heatmap
* Consistency
* Daily average
* Best day
* Longest streak
* Lifetime totals
* Most-used keys
* Key frequency visualization
* Keyboard usage heatmap
* Backspace rate
* Keystrokes per word
* Words per typing hour

### Privacy

OmaVibes stores aggregate statistics such as word totals, typing time, and key-press counts.

It does **not** store the actual text you type, typed sentences, key sequences, or per-key timestamps.

Analytics are stored locally on the device.

### Random

Click **Random** to choose a random soundpack.

When a search is active, random playback uses the currently filtered soundpacks.

### Turn Off

Click **Turn Off** to stop the currently playing typing sounds.

### Volume

Use the volume slider to adjust the current soundpack's volume from 1 to 10.

Each soundpack can have its own saved volume level.

## Soundpacks

OmaVibes includes the bundled soundpacks inside the `packs/` directory.

The soundpacks are included with the plugin so OmaVibes works immediately after installation without requiring users to download additional soundpacks.

### Custom Soundpacks

OmaVibes also supports user soundpacks through:

```text
~/wayvibes/<pack-name>/
```

A custom soundpack can contain the audio files required by `wayvibes` together with its `config.json`.

When a matching user soundpack exists, OmaVibes can use the user version instead of the bundled version.

## How It Works

OmaVibes is implemented as an Omarchy bar widget using Quickshell.

```text
BarWidget.qml
    |
    +-- Panel.qml
          |
          +-- OmaVibesState.qml
                  |
                  +-- Soundpack selection
                  +-- Search and filtering
                  +-- Random playback
                  +-- Volume control
                  +-- Profile and rank progression
                  +-- Typing statistics
                  +-- Key analytics
                  +-- Persistent settings
                  +-- wayvibes process control
```

The bundled `wayvibes` executable is located at:

```text
bin/wayvibes
```

The bundled soundpacks are located at:

```text
packs/
```

OmaVibes stores its persistent plugin state at:

```text
~/.local/state/omarchy/omavibes.json
```

Typing analytics are stored at:

```text
~/.local/state/omarchy/omavibes-analytics.json
```

## Repository Structure

```text
omavibes/
├── BarWidget.qml
├── Panel.qml
├── OmaVibesState.qml
├── manifest.json
├── qmldir
├── README.md
├── LICENSE
├── preview.png
├── bin/
│   └── wayvibes
├── packs/
│   └── <soundpacks>/
└── third_party/
    └── wayvibes/
```

## Development

From the plugin directory, validate the plugin with:

```bash
omarchy plugin validate .
```

Run QML linting against the Omarchy shell:

```bash
qmllint -I "$OMARCHY_PATH/shell" \
  BarWidget.qml \
  Panel.qml \
  OmaVibesState.qml
```

After making changes, restart the Omarchy shell:

```bash
omarchy restart shell
```

Rebuild the bundled Wayvibes runtime when changing its source:

```bash
./third_party/wayvibes/build.sh
```

### Before Publishing

Test the following:

* Bar icon appears correctly
* Panel opens and closes correctly
* Profile opens correctly
* Stats opens correctly
* Soundpack selection works
* Search filtering works
* Random playback works
* Turn Off works
* Volume control works
* Per-pack volume is preserved
* Typing statistics update correctly
* Key analytics update correctly
* Rank progress updates correctly
* Completed achievements appear correctly
* Shell restart does not break the plugin
* Plugin can be disabled and enabled again
* Plugin can be removed cleanly

## Removal

Disable the plugin:

```bash
omarchy plugin disable mshareef-git.omavibes
```

Remove the plugin:

```bash
omarchy plugin remove mshareef-git.omavibes
```

Removing the plugin does not remove user data stored outside the plugin directory, such as:

```text
~/.local/state/omarchy/omavibes.json
~/.local/state/omarchy/omavibes-analytics.json
~/wayvibes/
```

These can be removed separately if no longer needed.

## Credits

Built for Omarchy Quattro.

Omarchy: [https://omarchy.org/](https://omarchy.org/)

## License

OmaVibes is licensed under the MIT License.

See `LICENSE` for the complete license text.
