pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: state

    readonly property string pluginDir: decodeURIComponent(
        Qt.resolvedUrl("./").toString().replace(/^file:\/\//, "").replace(/\/$/, "")
    )
    readonly property string pluginBin: pluginDir + "/bin/wayvibes"
    readonly property string pluginPacksDir: pluginDir + "/packs/"
    readonly property string userPacksDir: Quickshell.env("HOME") + "/wayvibes/"
    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/omarchy/omavibes.json"
    readonly property string analyticsStateFile: Quickshell.env("HOME") + "/.local/state/omarchy/omavibes-analytics.json"
    readonly property string analyticsModeFile: Quickshell.env("HOME") + "/.local/state/omarchy/omavibes-analytics-mode"

    readonly property var packs: [
        { name: "akko lavender purples",                folder: "akko_lavender_purples" },
        { name: "nk cream",                             folder: "nk-cream" },
        { name: "cherrymx black abs",                   folder: "cherrymx-black-abs" },
        { name: "cherrymx black pbt",                   folder: "cherrymx-black-pbt" },
        { name: "cherrymx blue abs",                    folder: "cherrymx-blue-abs" },
        { name: "cherrymx blue pbt",                    folder: "cherrymx-blue-pbt" },
        { name: "cherrymx brown pbt",                   folder: "cherrymx-brown-pbt" },
        { name: "cherrymx red abs",                     folder: "cherrymx-red-abs" },
        { name: "cherrymx red pbt",                     folder: "cherrymx-red-pbt" },
        { name: "Chalks",                               folder: "chalks" },
        { name: "eg oreo",                              folder: "eg-oreo" },
        { name: "Lincoln Typewriter",                   folder: "Lincoln Typewriter" },
        { name: "Razer Green (Blackwidow Elite)",       folder: "Razer Green (Blackwidow Elite) - Akira" },
        { name: "penumbra",                             folder: "penumbra" },
        { name: "Thocks",                               folder: "Thocks" },
        { name: "osu",                                  folder: "osu" },
        { name: "banana split lubed",                   folder: "banana split lubed" },
        { name: "Water",                                folder: "water" },
        { name: "boxjade",                              folder: "boxjade" },
        { name: "bullet_passing",                       folder: "bullet_passing" },
        { name: "Cloth",                                folder: "cloth" },
        { name: "horse",                                folder: "horse" },
        { name: "Trust GXT 865 ASTA",                   folder: "Trust_GXT_865_ASTA" },
        { name: "sine bumps 2",                         folder: "sine bumps 2" },
        { name: "Press",                                folder: "Press" },
        { name: "Dino Alpacas",                         folder: "Dino_Alpacas" },
        { name: "Farts",                                folder: "Farts" },
        { name: "Glitch",                               folder: "glitch" },
        { name: "Kalimba",                              folder: "Kalimba" },
        { name: "animal crossing nl",                   folder: "animal_crossing_nl" },
        { name: "tealios v2 Akira",                     folder: "tealios-v2_Akira" },
        { name: "Koala",                                folder: "Koala" },
        { name: "Piano",                                folder: "Piano" },
        { name: "Saber",                                folder: "Saber" },
        { name: "shadowgun",                            folder: "shadowgun" },
        { name: "shutter",                              folder: "shutter" },
        { name: "trails in the sky",                    folder: "trails-in-the-sky" },
        { name: "Sword",                                folder: "Sword" },
        { name: "8 bit",                                folder: "8 bit" },
        { name: "Glass",                                folder: "Glass" },
        { name: "Fight",                                folder: "Fight" }
    ]

    property string currentPack: ""
    property bool isPlaying: false
    property var packVolumes: ({})
    property var keyboardDevices: []
    property string inputDevicePath: ""
    property bool stateLoaded: false
    property bool inputDeviceLoaded: false
    property bool playbackRestored: false
    readonly property int defaultVolume: 3

    function volumeFor(packName) {
        return packVolumes[packName] !== undefined ? packVolumes[packName] : defaultVolume
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    function restorePlayback() {
        if (playbackRestored || !stateLoaded || !inputDeviceLoaded || !currentPack || !inputDevicePath)
            return

        playbackRestored = true
        play(currentPack)
    }

    function play(packName) {
        const pack = packs.find(p => p.name === packName)
        if (!pack) return

        stopProc.running = true
        stopProc.exited.connect(function onExit() {
            stopProc.exited.disconnect(onExit)
            startTimer.packFolder = pack.folder
            startTimer.packName = pack.name
            startTimer.start()
        })
    }

    function stop() {
        stopProc.running = true
        state.currentPack = ""
        state.isPlaying = false
        save()
        if (state.trackingMode === "always") {
            startAnalyticsAfterStopTimer.restart()
        }
    }

    property Timer startAnalyticsAfterStopTimer: Timer {
        interval: 300
        repeat: false
        onTriggered: state.startAnalyticsProcess()
    }

    function setVolume(vol) {
        if (!currentPack) return
        packVolumes[currentPack] = vol
        packVolumesChanged()
        save()
        play(currentPack)
    }

    function randomPack() {
        if (packs.length === 0) return
        const p = packs[Math.floor(Math.random() * packs.length)]
        play(p.name)
    }

    function loadKeyboardDevices() {
        keyboardDeviceProc.running = true
    }

    function selectInputDevice(path) {
        if (!path)
            return

        inputDevicePath = path
        const quotedPath = shellQuote(path)
        writeInputDeviceProc.command = [
            "bash", "-c",
            "mkdir -p ~/.config/wayvibes && printf '%s' " + quotedPath +
                " > ~/.config/wayvibes/input_device_path"
        ]
        writeInputDeviceProc.running = true

        if (currentPack)
            play(currentPack)
    }

    property Process stopProc: Process {
        command: ["pkill", "-x", "wayvibes"]
    }

    property Timer startTimer: Timer {
        id: startTimer
        interval: 300
        property string packFolder: ""
        property string packName: ""

        onTriggered: {
            const volumeValue = Number(state.volumeFor(packName))
            const volume = Number.isFinite(volumeValue)
                ? Math.max(1, Math.min(10, Math.round(volumeValue)))
                : state.defaultVolume

            const pluginBin = shellQuote(state.pluginBin)
            const pluginPackDir = shellQuote(state.pluginPacksDir + packFolder)
            const userPackDir = shellQuote(state.userPacksDir + packFolder)

            const launchCmd =
                "BIN=" + pluginBin + "; " +
                "PACK_DIR=" + pluginPackDir + "; " +
                "[ -d " + userPackDir + " ] && PACK_DIR=" + userPackDir + "; " +
                "if [ \"" + String(state.trackingMode) + "\" = \"always\" ]; then " +
                "$BIN \"$PACK_DIR/\" -v " + String(volume) + " --no-analytics -bg; " +
                "$BIN --analytics-only --background; " +
                "else " +
                "$BIN \"$PACK_DIR/\" -v " + String(volume) + " -bg; " +
                "fi"

            launchProc.command = ["bash", "-c", launchCmd]
            launchProc.running = true

            state.currentPack = packName
            state.isPlaying = true
            state.save()
        }
    }

    property Process launchProc: Process {}

    property Process keyboardDeviceProc: Process {
        command: [state.pluginBin, "--list-devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                const devices = text.trim().split("\n").filter(Boolean).map(function(line) {
                    const parts = line.split("\t")
                    return { path: parts[0], name: parts.slice(1).join("\t") || parts[0] }
                })
                state.keyboardDevices = devices
            }
        }
    }

    property Process inputDeviceReadProc: Process {
        command: ["bash", "-c", "cat ~/.config/wayvibes/input_device_path 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                state.inputDevicePath = text.trim()
                state.inputDeviceLoaded = true
                state.restorePlayback()
            }
        }
    }

    property Process writeInputDeviceProc: Process {}

    function load() {
        readProc.running = true
    }

    function save() {
        const payload = JSON.stringify({
            currentPack: currentPack,
            packVolumes: packVolumes
        })
        const safePayload = payload.replace(/'/g, "'\\''")
        writeProc.command = [
            "bash", "-c",
            "mkdir -p ~/.local/state/omarchy && printf '%s' '" + safePayload + "' > '" + stateFile + "'"
        ]
        writeProc.running = true
    }

    property Process writeProc: Process {}

    property Process readProc: Process {
        id: readProc
        command: ["bash", "-c", "cat '" + state.stateFile + "' 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (data.currentPack) state.currentPack = data.currentPack
                    if (data.packVolumes) state.packVolumes = data.packVolumes
                    state.isPlaying = false
                } catch (e) {
                }
                state.stateLoaded = true
                state.restorePlayback()
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // ANALYTICS
    // Data is local and stores only aggregate counts/timing.
    // The actual typed content is never stored.
    // ─────────────────────────────────────────────────────────────

    property var dailyWords: ({})
    property var dailyTypingSeconds: ({})
    property var dailyTrackedSeconds: ({})
    property var keyCounts: ({})
    property double totalKeyPresses: 0

    // onlyWhenSound = track while a soundpack is playing
    // always         = track whenever OmaVibes is loaded
    property string trackingMode: "onlyWhenSound"
    property bool trackingModePreferenceLoaded: false

    // Number of character-like keys currently present in the unfinished word.
    // This is only a counter; no typed characters are retained.
    property int currentWordLength: 0
    property double lastKeypressEpoch: 0
    property double trackingLastEpoch: 0

    readonly property bool analyticsTrackingActive:
        trackingMode === "always" || (trackingMode === "onlyWhenSound" && isPlaying)

    readonly property var dayShortNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var monthShortNames: [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]

    function cloneObject(source) {
        const result = {}
        for (const key in source) result[key] = source[key]
        return result
    }

    function dateKeyFor(date) {
        const y = date.getFullYear()
        const m = String(date.getMonth() + 1).padStart(2, "0")
        const d = String(date.getDate()).padStart(2, "0")
        return y + "-" + m + "-" + d
    }

    function parseDateKey(key) {
        const parts = String(key).split("-")
        if (parts.length !== 3) return new Date()
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
    }

    function todayKey() {
        return dateKeyFor(new Date())
    }

    function dayStart(date) {
        return new Date(date.getFullYear(), date.getMonth(), date.getDate(), 0, 0, 0, 0)
    }

    function nextDayStart(date) {
        const next = dayStart(date)
        next.setDate(next.getDate() + 1)
        return next
    }

    function startOfWeek(date) {
        const start = dayStart(date)
        start.setDate(start.getDate() - start.getDay())
        return start
    }

    function endOfWeek(date) {
        const end = startOfWeek(date)
        end.setDate(end.getDate() + 6)
        return end
    }

    function daysInMonth(year, monthIndex) {
        return new Date(year, monthIndex + 1, 0).getDate()
    }

    function addDays(date, amount) {
        const result = new Date(date)
        result.setDate(result.getDate() + amount)
        return result
    }

    function addMonths(date, amount) {
        const result = new Date(date)
        result.setDate(1)
        result.setMonth(result.getMonth() + amount)
        return result
    }

    function addWeeks(date, amount) {
        return addDays(date, amount * 7)
    }

    function wordsOn(dayKey) {
        return Number(dailyWords[dayKey] || 0)
    }

    function typingSecondsOn(dayKey) {
        return Number(dailyTypingSeconds[dayKey] || 0)
    }

    function trackedSecondsOn(dayKey) {
        return Number(dailyTrackedSeconds[dayKey] || 0)
    }

    function idleSecondsOn(dayKey) {
        return Math.max(0, trackedSecondsOn(dayKey) - typingSecondsOn(dayKey))
    }

    function todayWords() {
        return wordsOn(todayKey())
    }

    // Lifetime progression. These values are derived from the existing
    // daily aggregate data; no new persistent fields are required.
    // 25 lifetime word tiers. The progression is intentionally front-loaded
    // so early users get frequent unlocks, then spaces out for long-term play.
    readonly property var typingTiers: [
        { min: 0,        name: "Dust",               symbol: "◌" },
        { min: 500,      name: "Ember",              symbol: "◆" },
        { min: 1000,     name: "Twig",               symbol: "✦" },
        { min: 2000,     name: "Puddle",             symbol: "◇" },
        { min: 4000,     name: "Bronze I",           symbol: "●" },
        { min: 6000,     name: "Bronze II",          symbol: "●" },
        { min: 8000,     name: "Copper I",           symbol: "⬢" },
        { min: 10000,    name: "Iron I",             symbol: "⚙" },
        { min: 15000,    name: "Obsidian",            symbol: "⬟" },
        { min: 25000,    name: "Scout",               symbol: "⌖" },
        { min: 30000,    name: "Silver I",            symbol: "◇" },
        { min: 50000,    name: "Gold I",              symbol: "✪" },
        { min: 75000,    name: "Platinum II",         symbol: "◈" },
        { min: 100000,   name: "Emerald III",         symbol: "◆" },
        { min: 150000,   name: "Crystal I",           symbol: "❖" },
        { min: 250000,   name: "Warden",              symbol: "⬢" },
        { min: 400000,   name: "Diamond I",           symbol: "◇" },
        { min: 600000,   name: "Ruby III",            symbol: "◆" },
        { min: 1000000,  name: "Sapphire IV",         symbol: "◆" },
        { min: 1500000,  name: "Blademaster",         symbol: "✦" },
        { min: 2500000,  name: "Arcane Ranger",       symbol: "✧" },
        { min: 5000000,  name: "Grandmaster I",       symbol: "✪" },
        { min: 10000000, name: "Legend III",           symbol: "★" },
        { min: 15000000, name: "Ace Diamond",          symbol: "◇" },
        { min: 25000000, name: "Conqueror Platinum",  symbol: "❖" }
    ]

    function lifetimeWords() {
        let total = 0
        for (const key in dailyWords)
            total += Number(dailyWords[key] || 0)
        return total
    }

    function lifetimeTypingSeconds() {
        let total = 0
        for (const key in dailyTypingSeconds)
            total += Number(dailyTypingSeconds[key] || 0)
        return total
    }

    function lifetimeTrackedSeconds() {
        let total = 0
        for (const key in dailyTrackedSeconds)
            total += Number(dailyTrackedSeconds[key] || 0)
        return total
    }

    function lifetimeActiveDays() {
        let total = 0
        for (const key in dailyWords)
            if (Number(dailyWords[key] || 0) > 0) ++total
        return total
    }

    function lifetimeBestDay() {
        let bestWords = 0
        let bestDate = ""
        for (const key in dailyWords) {
            const words = Number(dailyWords[key] || 0)
            if (words > bestWords) {
                bestWords = words
                bestDate = key
            }
        }
        return { words: bestWords, date: bestDate }
    }

    function lifetimeLongestStreak() {
        const keys = Object.keys(dailyWords).filter(
            key => Number(dailyWords[key] || 0) > 0
        ).sort()

        if (keys.length === 0) return 0

        let best = 1
        let current = 1
        for (let i = 1; i < keys.length; ++i) {
            const prev = parseDateKey(keys[i - 1])
            const cur = parseDateKey(keys[i])
            const diff = Math.round((dayStart(cur) - dayStart(prev)) / 86400000)
            if (diff === 1) {
                ++current
                best = Math.max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    function lifetimeTier() {
        const words = lifetimeWords()
        let current = typingTiers[0]
        for (let i = 0; i < typingTiers.length; ++i) {
            if (words >= typingTiers[i].min)
                current = typingTiers[i]
            else
                break
        }
        return current
    }

    function lifetimeTierIndex() {
        const words = lifetimeWords()
        let index = 0
        for (let i = 0; i < typingTiers.length; ++i) {
            if (words >= typingTiers[i].min) index = i
            else break
        }
        return index
    }

    function lifetimeNextTier() {
        const index = lifetimeTierIndex()
        return index + 1 < typingTiers.length
            ? typingTiers[index + 1]
            : null
    }

    function lifetimeTierProgress() {
        const words = lifetimeWords()
        const index = lifetimeTierIndex()
        const current = typingTiers[index]
        const next = lifetimeNextTier()
        if (!next) return 1
        const span = next.min - current.min
        if (span <= 0) return 1
        return Math.max(0, Math.min(1, (words - current.min) / span))
    }

    function lifetimeWordsToNextTier() {
        const next = lifetimeNextTier()
        return next ? Math.max(0, next.min - lifetimeWords()) : 0
    }

    function profileAchievements() {
        const words = lifetimeWords()
        const best = lifetimeBestDay().words
        const streak = lifetimeLongestStreak()
        const keys = lifetimeKeyPresses()

        return [
            { name: "First 100", detail: "100 lifetime words", symbol: "✓", unlocked: words >= 100 },
            { name: "First 1K", detail: "1,000 lifetime words", symbol: "✦", unlocked: words >= 1000 },
            { name: "10K Club", detail: "10,000 lifetime words", symbol: "◆", unlocked: words >= 10000 },
            { name: "100K Club", detail: "100,000 lifetime words", symbol: "◇", unlocked: words >= 100000 },
            { name: "Million Words", detail: "1,000,000 lifetime words", symbol: "★", unlocked: words >= 1000000 },
            { name: "Keysmith", detail: "100,000 key presses", symbol: "⚙", unlocked: keys >= 100000 },
            { name: "Key Hoarder", detail: "1,000,000 key presses", symbol: "⬢", unlocked: keys >= 1000000 },
            { name: "Big Day", detail: "5,000 words in one day", symbol: "▲", unlocked: best >= 5000 },
            { name: "Monster Day", detail: "10,000 words in one day", symbol: "◆", unlocked: best >= 10000 },
            { name: "Week Warrior", detail: "7 day typing streak", symbol: "↗", unlocked: streak >= 7 },
            { name: "Month Warrior", detail: "30 day typing streak", symbol: "◈", unlocked: streak >= 30 },
            { name: "Century Streak", detail: "100 day typing streak", symbol: "∞", unlocked: streak >= 100 }
        ].filter(function(item) { return item.unlocked })
    }

    // Lifetime key analytics. Only aggregate counts are used; no text or
    // key sequences are reconstructed here.
    function lifetimeKeyPresses() {
        let total = 0
        for (const key in keyCounts)
            total += Number(keyCounts[key] || 0)
        return total
    }

    function keyCount(keyLabel) {
        return Number(keyCounts[String(keyLabel).toUpperCase()] || 0)
    }

    function mostUsedKeys(limit) {
        const result = []
        for (const key in keyCounts) {
            const count = Number(keyCounts[key] || 0)
            if (count > 0) result.push({ key: key, count: count })
        }
        result.sort(function(a, b) {
            if (b.count !== a.count) return b.count - a.count
            return a.key.localeCompare(b.key)
        })
        return result.slice(0, Math.max(0, Number(limit) || 0))
    }

    function keyCategoryCounts() {
        let letters = 0
        let digits = 0
        let special = 0

        for (const key in keyCounts) {
            const count = Number(keyCounts[key] || 0)
            if (/^[A-Z]$/.test(key)) letters += count
            else if (/^[0-9]$/.test(key)) digits += count
            else special += count
        }

        return { letters: letters, digits: digits, special: special }
    }

    function backspaceRate() {
        const total = lifetimeKeyPresses()
        return total > 0 ? keyCount("BACKSPACE") / total * 100 : 0
    }

    function keyMixInsight() {
        const total = lifetimeKeyPresses()
        if (total <= 0) return { label: "No key data yet", percent: 0 }

        const mix = keyCategoryCounts()
        const entries = [
            { label: "Letters", value: mix.letters },
            { label: "Digits", value: mix.digits },
            { label: "Special", value: mix.special }
        ]

        entries.sort(function(a, b) { return b.value - a.value })
        return {
            label: entries[0].label,
            percent: entries[0].value / total * 100
        }
    }

    function lifetimeAverageWordsPerActiveDay() {
        const days = lifetimeActiveDays()
        return days > 0 ? lifetimeWords() / days : 0
    }

    function wordsPerTypingHour() {
        const seconds = lifetimeTypingSeconds()
        return seconds > 0 ? lifetimeWords() / (seconds / 3600) : 0
    }

    // One playful remark for today only. The bucket changes automatically
    // when today's word total crosses a threshold.
    function todayRemarkText() {
        const words = todayWords()
        const day = todayKey()

        const buckets = [
            // 0 words
            {
                max: 0,
                remarks: [
                    "Keyboard's feeling lonely today.",
                    "Not a single word. Ouch.",
                    "You really didn't need me today, huh?",
                    "The keys were waiting for you.",
                    "Absolutely nothing. Impressive!! Seeenior",
                    "Keyboard-sama has been abandoned.",
                    "Maybe tomorrow...",
                    "Not even one word? Seriously?",
                    "The keyboard has officially been ignored.",
                    "Fine. I'll pretend today never happened."
                ]
            },

            // 1–250
            {
                max: 250,
                remarks: [
                    "{words} words — Just warming up, huh?",
                    "That's... technically typing. {words} words.",
                    "{words} words — Baby steps, I guess.",
                    "We made some progress. {words} words.",
                    "{words} goblin words — a tiny little start.",
                    "Only {words} words? I'll allow it.",
                    "{words} words — The keyboard survived.",
                    "A respectable pile of potato words: {words}.",
                    "{words} words — Not terrible.",
                    "You showed up. Barely. {words} words."
                ]
            },

            // 251–500
            {
                max: 500,
                remarks: [
                    "{words} words — Okay, now we're talking.",
                    "That's actually respectable. {words} words.",
                    "{words} words — Look who's getting stuff done.",
                    "Not bad. {words} words.",
                    "{words} words — The keys are getting some exercise.",
                    "Hmm. {words} words. You're improving.",
                    "Fine. {words} words is pretty decent.",
                    "{words} words — That's a nice little banana pile.",
                    "You're becoming slightly useful. {words} words.",
                    "{words} words — Don't get too proud."
                ]
            },

            // 501–1000
            {
                max: 1000,
                remarks: [
                    "{words} words — Okay, you're cooking.",
                    "{words} words — Now we're getting somewhere.",
                    "DAMN. {words} words.",
                    "{words} words — The keyboard is putting in work.",
                    "You had a lot to say today. {words} words.",
                    "{words} words — That's some serious typing.",
                    "Alright... {words} words. I'm impressed. A little.",
                    "{words} words — That's an unhealthy amount of keyboard activity.",
                    "The keys are eating well today. {words} words.",
                    "{words} goblin words — now this is getting serious."
                ]
            },

            // 1001–1500
            {
                max: 1500,
                remarks: [
                    "{words} words — Well... someone had a lot to say.",
                    "Look at you go. {words} words.",
                    "{words} words — Keyboard-sama is getting nervous.",
                    "That's quite a workload. {words} words.",
                    "{words} words — You're starting to scare the keys.",
                    "I suppose {words} words isn't bad.",
                    "{words} words — Don't expect me to praise you too much.",
                    "{words} words — That's quite a mountain of carrot sentences.",
                    "You really kept going, huh? {words} words.",
                    "{words} words — Fine. I'm a little impressed."
                ]
            },

            // 1501–2000
            {
                max: 2000,
                remarks: [
                    "{words} words — Bro was NOT finished.",
                    "Seriously? {words} words?",
                    "{words} words — You're really keeping those keys busy.",
                    "The keyboard is working overtime for you.",
                    "{words} words — That's a whole lot of typing.",
                    "Hmm... {words} words. That's actually impressive.",
                    "{words} words — You really woke up and chose typing.",
                    "Fine. {words} words. I'll admit that's good.",
                    "{words} words — That's an entire basket of keyboard bananas.",
                    "You weren't typing. You were farming words. {words} of them."
                ]
            },

            // 2001–3000
            {
                max: 3000,
                remarks: [
                    "{words} words — Okay, commander, calm down.",
                    "{words} words — You really had things to say today.",
                    "Keyboard-sama requests a vacation. {words} words.",
                    "{words} words — You're turning this into a full-time job.",
                    "Senior... {words} words is getting ridiculous.",
                    "{words} words — I didn't say you could go this hard.",
                    "Alright, {words} words. That's genuinely impressive.",
                    "{words} words — Who gave you this much motivation?",
                    "You're on a mission today. {words} words.",
                    "{words} words — Don't look at me. I'm impressed too."
                ]
            },

            // 3001–4000
            {
                max: 4000,
                remarks: [
                    "{words} words — Bro is on a mission.",
                    "The keyboard is earning its salary. {words} words.",
                    "{words} words — Productivity buff activated.",
                    "You basically moved into the keyboard. {words} words.",
                    "{words} words — Those keys are working overtime.",
                    "Senior has entered serious typing mode. {words} words.",
                    "{words} words — Yeah... you're cooking HARD."
                ]
            },

            // 4001–10000
            {
                max: 10000,
                remarks: [
                    "BRO. {words} WORDS.",
                    "{words} words — The keyboard deserves a break.",
                    "This is getting concerning. {words} words.",
                    "{words} words — You have A LOT to say.",
                    "Keyboard abuse detected: {words} words.",
                    "{words} words — The keys need therapy.",
                    "Okay... {words} words is actually absurd."
                ]
            },

            // 10001–20000
            {
                max: 20000,
                remarks: [
                    "{words} words — Bro wrote an entire civilization.",
                    "You practically emptied the dictionary. {words} words.",
                    "{words} words — The keyboard fears you now.",
                    "This isn't typing anymore. It's warfare. {words} words.",
                    "{words} words — HOW are you still typing?",
                    "Your keyboard has entered survival mode. {words} words.",
                    "{words} words — Senior, please put the keyboard down."
                ]
            },

            // 20001–30000
            {
                max: 30000,
                remarks: [
                    "{words} words — This keyboard is fighting for its life.",
                    "{words} words — You are absolutely relentless.",
                    "Still typing? {words} words. Seriously?",
                    "{words} words — The keys have accepted their fate.",
                    "Commander, the keyboard cannot keep up. {words} words.",
                    "{words} words — At this point you're writing history.",
                    "I refuse to believe that number. {words} words."
                ]
            },

            // 30001–50000
            {
                max: 50000,
                remarks: [
                    "{words} words — Bro is writing the sequel too.",
                    "Your keyboard has officially surrendered. {words} words.",
                    "{words} words — This is no longer a normal workday.",
                    "Senior... what exactly are you writing? {words} words.",
                    "{words} words — Keyboard-sama has left the battlefield.",
                    "You didn't type all that... right? {words} words.",
                    "{words} words — This is getting legendary."
                ]
            },

            // 50001–100000
            {
                max: 100000,
                remarks: [
                    "{words} words — You didn't type. You conquered.",
                    "The keyboard deserves hazard pay. {words} words.",
                    "{words} words — At this point, you're generating literature.",
                    "Commander, the keyboard has officially surrendered. {words} words.",
                    "{words} words — You have transcended ordinary typing.",
                    "Senior... I have no idea how you did that. {words} words.",
                    "{words} words — That's not productivity anymore. That's domination."
                ]
            },

            // 100001+
            {
                max: Number.POSITIVE_INFINITY,
                remarks: [
                    "{words} words — I have no idea what to say anymore.",
                    "{words} words — The keyboard is now legally your employee.",
                    "You have broken the concept of 'a lot'. {words} words.",
                    "{words} words — Keyboard-sama requests retirement.",
                    "Senior... please. {words} words.",
                    "{words} words — This is no longer human-scale typing.",
                    "{words} words — I surrender."
                ]
            }
        ]

        let bucket = buckets[buckets.length - 1]

        for (let i = 0; i < buckets.length; ++i) {
            if (words <= buckets[i].max) {
                bucket = buckets[i]
                break
            }
        }

        let seed = 0

        for (let i = 0; i < day.length; ++i) {
            seed = ((seed * 31) + day.charCodeAt(i)) >>> 0
        }

        const remark = bucket.remarks[seed % bucket.remarks.length]

        return remark.replace(/\{words\}/g, words.toLocaleString())
    }

    function yesterdayKey() {
        return dateKeyFor(addDays(new Date(), -1))
    }

    function yesterdayWords() {
        return wordsOn(yesterdayKey())
    }

    function wordsChangePercent() {
        const current = todayWords()
        const previous = yesterdayWords()
        if (previous <= 0) return current > 0 ? 100 : 0
        return ((current - previous) / previous) * 100
    }

    function monthPrefix(date) {
        return date.getFullYear() + "-" + String(date.getMonth() + 1).padStart(2, "0")
    }

    function sumWords(startDate, endDateInclusive) {
        let total = 0
        let cursor = dayStart(startDate)
        const end = dayStart(endDateInclusive)
        while (cursor <= end) {
            total += wordsOn(dateKeyFor(cursor))
            cursor = addDays(cursor, 1)
        }
        return total
    }

    function sumTypingSeconds(startDate, endDateInclusive) {
        let total = 0
        let cursor = dayStart(startDate)
        const end = dayStart(endDateInclusive)
        while (cursor <= end) {
            total += typingSecondsOn(dateKeyFor(cursor))
            cursor = addDays(cursor, 1)
        }
        return total
    }

    function sumTrackedSeconds(startDate, endDateInclusive) {
        let total = 0
        let cursor = dayStart(startDate)
        const end = dayStart(endDateInclusive)
        while (cursor <= end) {
            total += trackedSecondsOn(dateKeyFor(cursor))
            cursor = addDays(cursor, 1)
        }
        return total
    }

    function formatDuration(totalSeconds) {
        const seconds = Math.max(0, Math.round(Number(totalSeconds) || 0))
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        if (hours > 0) return hours + "h " + minutes + "m"
        return minutes + "m"
    }

    function formatSignedPercent(value) {
        const number = Number(value) || 0
        const sign = number > 0 ? "+" : ""
        return sign + number.toFixed(1) + "%"
    }

    // The bundled wayvibes binary owns keyboard analytics and persistence.
    // QML only controls the process mode and reads aggregate data for charts.

    function startAnalyticsProcess() {
        if (state.trackingMode !== "always") return
        if (analyticsOnlyProc.running) return

        analyticsOnlyProc.command = [state.pluginBin, "--analytics-only", "--background"]
        analyticsOnlyProc.running = true
    }

    function setTrackingMode(mode) {
        if (mode !== "onlyWhenSound" && mode !== "always") return
        if (trackingMode === mode) return

        trackingMode = mode

        const safeMode = mode.replace(/'/g, "'\\''")
        analyticsModeWriteProc.command = [
            "bash", "-c",
            "mkdir -p ~/.local/state/omarchy && printf '%s' '" + safeMode + "' > '" + analyticsModeFile + "'"
        ]
        analyticsModeWriteProc.running = true

        if (isPlaying && currentPack) {
            play(currentPack)
        } else if (mode === "always") {
            startAnalyticsProcess()
        } else {
            stopProc.running = true
        }
    }

    function loadAnalytics() {
        if (!analyticsReadProc.running) analyticsReadProc.running = true
    }

    function loadTrackingMode() {
        analyticsModeReadProc.running = true
    }

    property Timer analyticsRefreshTimer: Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: state.loadAnalytics()
    }

    property Process analyticsWriteProc: Process {}
    property Process analyticsModeWriteProc: Process {}
    property Process analyticsOnlyProc: Process {}

    property Process analyticsModeReadProc: Process {
        id: analyticsModeReadProc
        command: ["bash", "-c", "cat '" + state.analyticsModeFile + "' 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                state.trackingModePreferenceLoaded = true
                const mode = String(text).trim()
                if (mode === "onlyWhenSound" || mode === "always") {
                    state.trackingMode = mode
                    if (mode === "always" && !state.isPlaying) state.startAnalyticsProcess()
                } else {
                    state.loadAnalytics()
                }
            }
        }
    }

    property Process analyticsReadProc: Process {
        id: analyticsReadProc
        command: ["bash", "-c", "cat '" + state.analyticsStateFile + "' 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (data.dailyWords) state.dailyWords = data.dailyWords
                    if (data.dailyTypingSeconds) state.dailyTypingSeconds = data.dailyTypingSeconds
                    if (data.dailyTrackedSeconds) state.dailyTrackedSeconds = data.dailyTrackedSeconds
                    if (data.keyCounts) state.keyCounts = data.keyCounts
                    state.totalKeyPresses = Number(data.totalKeyPresses || 0)
                    if (!state.totalKeyPresses)
                        state.totalKeyPresses = state.lifetimeKeyPresses()
                    if (!state.trackingModePreferenceLoaded &&
                        (data.trackingMode === "onlyWhenSound" || data.trackingMode === "always")) {
                        state.trackingMode = data.trackingMode
                        if (data.trackingMode === "always" && !state.isPlaying) state.startAnalyticsProcess()
                    }
                } catch (e) {
                    console.log("OmaVibes analytics: could not read analytics state")
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Calendar / chart helpers
    // ─────────────────────────────────────────────────────────────

    function weekLabel(date) {
        const d = new Date(date)
        d.setHours(0, 0, 0, 0)
        d.setDate(d.getDate() + 3 - ((d.getDay() + 6) % 7))
        const week1 = new Date(d.getFullYear(), 0, 4)
        const week = 1 + Math.round(((d - week1) / 86400000 - 3 + ((week1.getDay() + 6) % 7)) / 7)
        return "W" + week
    }

    function periodTitle(mode, anchorDate) {
        const date = new Date(anchorDate)
        if (mode === "day") {
            return monthShortNames[date.getMonth()] + " " + date.getDate() + ", " + date.getFullYear()
        }
        if (mode === "week") {
            const start = startOfWeek(date)
            const end = endOfWeek(date)
            return monthShortNames[start.getMonth()] + " " + start.getDate() + " – " +
                   monthShortNames[end.getMonth()] + " " + end.getDate() + " " + end.getFullYear()
        }
        return monthShortNames[date.getMonth()] + " " + date.getFullYear()
    }

    // Seven real calendar days containing the selected day.
    function dayChart(anchorDate) {
        const start = startOfWeek(anchorDate)
        const result = []
        for (let i = 0; i < 7; i++) {
            const date = addDays(start, i)
            result.push({
                key: dateKeyFor(date),
                label: dayShortNames[date.getDay()],
                date: date.getDate(),
                value: wordsOn(dateKeyFor(date)),
                typingSeconds: typingSecondsOn(dateKeyFor(date)),
                trackedSeconds: trackedSecondsOn(dateKeyFor(date)),
                idleSeconds: idleSecondsOn(dateKeyFor(date)),
                isToday: dateKeyFor(date) === todayKey()
            })
        }
        return result
    }

    // Eight real calendar weeks ending at the week containing anchorDate.
    function weekChart(anchorDate) {
        const currentWeek = startOfWeek(anchorDate)
        const result = []
        for (let i = 7; i >= 0; i--) {
            const start = addWeeks(currentWeek, -i)
            const end = endOfWeek(start)
            result.push({
                key: dateKeyFor(start),
                label: weekLabel(start),
                value: sumWords(start, end),
                typingSeconds: sumTypingSeconds(start, end),
                trackedSeconds: sumTrackedSeconds(start, end),
                idleSeconds: Math.max(0, sumTrackedSeconds(start, end) - sumTypingSeconds(start, end)),
                isCurrent: dateKeyFor(start) === dateKeyFor(currentWeek)
            })
        }
        return result
    }

    // Six real calendar months ending at the month containing anchorDate.
    function monthChart(anchorDate) {
        const currentMonth = new Date(anchorDate.getFullYear(), anchorDate.getMonth(), 1)
        const result = []
        for (let i = 5; i >= 0; i--) {
            const month = addMonths(currentMonth, -i)
            const start = new Date(month.getFullYear(), month.getMonth(), 1)
            const end = new Date(month.getFullYear(), month.getMonth() + 1, 0)
            const tracked = sumTrackedSeconds(start, end)
            const typing = sumTypingSeconds(start, end)
            result.push({
                key: monthPrefix(month),
                label: monthShortNames[month.getMonth()],
                value: sumWords(start, end),
                typingSeconds: typing,
                trackedSeconds: tracked,
                idleSeconds: Math.max(0, tracked - typing),
                isCurrent: monthPrefix(month) === monthPrefix(currentMonth)
            })
        }
        return result
    }

    function chartForMode(mode, anchorDate) {
        if (mode === "week") return weekChart(anchorDate)
        if (mode === "month") return monthChart(anchorDate)
        return dayChart(anchorDate)
    }

    function periodTotals(mode, anchorDate) {
        const date = new Date(anchorDate)
        let start
        let end

        if (mode === "week") {
            start = startOfWeek(date)
            end = endOfWeek(date)
        } else if (mode === "month") {
            start = new Date(date.getFullYear(), date.getMonth(), 1)
            end = new Date(date.getFullYear(), date.getMonth() + 1, 0)
        } else {
            start = dayStart(date)
            end = start
        }

        const typing = sumTypingSeconds(start, end)
        const tracked = sumTrackedSeconds(start, end)
        return {
            words: sumWords(start, end),
            typingSeconds: typing,
            trackedSeconds: tracked,
            idleSeconds: Math.max(0, tracked - typing)
        }
    }

    function typingIdlePercentages(mode, anchorDate) {
        const totals = periodTotals(mode, anchorDate)
        const total = totals.typingSeconds + totals.idleSeconds
        if (total <= 0) return { typingPercent: 0, idlePercent: 0 }
        return {
            typingPercent: totals.typingSeconds / total * 100,
            idlePercent: totals.idleSeconds / total * 100
        }
    }

    function currentPeriodWords(mode, anchorDate) {
        return periodTotals(mode, anchorDate).words
    }

    function shiftPeriod(anchorDate, mode, direction) {
        const date = new Date(anchorDate)
        if (mode === "week") return addWeeks(date, direction)
        if (mode === "month") return addMonths(date, direction)
        return addDays(date, direction)
    }


    // ─────────────────────────────────────────────────────────────
    // ANALYTICS UI HELPERS
    // These functions only transform the aggregate maps already
    // loaded from analyticsStateFile. They never write analytics data.
    // ─────────────────────────────────────────────────────────────

    property var analyticsAnchor: new Date()

    function formatDurationPrecise(totalSeconds) {
        const seconds = Math.max(0, Math.round(Number(totalSeconds) || 0))
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        const secs = seconds % 60

        if (hours > 0)
            return hours + "h " + minutes + "m"
        if (minutes > 0)
            return minutes + "m " + secs + "s"
        return secs + "s"
    }

    function resetAnalyticsPeriod() {
        analyticsAnchor = new Date()
    }

    function moveAnalyticsPeriod(direction, mode) {
        analyticsAnchor = shiftPeriod(analyticsAnchor, mode, Number(direction) || 0)
    }

    function analyticsPeriodLabel(mode) {
        const anchor = new Date(analyticsAnchor)

        if (mode === "week") {
            const start = startOfWeek(anchor)
            const end = endOfWeek(anchor)
            return monthShortNames[start.getMonth()] + " " +
                   start.getDate() + " – " +
                   monthShortNames[end.getMonth()] + " " +
                   end.getDate() + ", " +
                   end.getFullYear()
        }

        if (mode === "month") {
            return monthShortNames[anchor.getMonth()] + " " +
                   anchor.getFullYear()
        }

        const start = startOfWeek(anchor)
        const end = endOfWeek(anchor)
        return monthShortNames[start.getMonth()] + " " +
               start.getDate() + " – " +
               monthShortNames[end.getMonth()] + " " +
               end.getDate() + ", " +
               end.getFullYear() + " • W" + weekNumber(start)
    }

    function weekNumber(date) {
        const d = new Date(date)
        d.setHours(0, 0, 0, 0)
        d.setDate(d.getDate() + 3 - ((d.getDay() + 6) % 7))
        const week1 = new Date(d.getFullYear(), 0, 4)
        return 1 + Math.round(
            ((d - week1) / 86400000 -
             3 + ((week1.getDay() + 6) % 7)) / 7
        )
    }

    function seriesWindow(mode) {
        const anchor = new Date(analyticsAnchor)
        const result = []

        if (mode === "month") {
            // Twelve calendar months ending at the selected month.
            const selectedMonth = new Date(anchor.getFullYear(), anchor.getMonth(), 1)
            for (let i = 11; i >= 0; --i) {
                const d = new Date(selectedMonth.getFullYear(), selectedMonth.getMonth() - i, 1)
                result.push({
                    key: dateKeyFor(d),
                    label: monthShortNames[d.getMonth()],
                    value: sumWords(
                        new Date(d.getFullYear(), d.getMonth(), 1),
                        new Date(d.getFullYear(), d.getMonth() + 1, 0)
                    ),
                    typingSeconds: sumTypingSeconds(
                        new Date(d.getFullYear(), d.getMonth(), 1),
                        new Date(d.getFullYear(), d.getMonth() + 1, 0)
                    ),
                    trackedSeconds: sumTrackedSeconds(
                        new Date(d.getFullYear(), d.getMonth(), 1),
                        new Date(d.getFullYear(), d.getMonth() + 1, 0)
                    ),
                    isToday: d.getFullYear() === new Date().getFullYear() &&
                             d.getMonth() === new Date().getMonth()
                })
            }
            return result
        }

        if (mode === "week") {
            // Eight weekly points, ending at the selected week.
            const selectedWeek = startOfWeek(anchor)
            for (let i = 7; i >= 0; --i) {
                const start = addDays(selectedWeek, -i * 7)
                const end = addDays(start, 6)
                result.push({
                    key: dateKeyFor(start),
                    label: monthShortNames[start.getMonth()] + " " + start.getDate(),
                    value: sumWords(start, end),
                    typingSeconds: sumTypingSeconds(start, end),
                    trackedSeconds: sumTrackedSeconds(start, end),
                    isToday: dateKeyFor(startOfWeek(new Date())) === dateKeyFor(start)
                })
            }
            return result
        }

        // Day view: the selected calendar week, one point per real day.
        const start = startOfWeek(anchor)
        for (let i = 0; i < 7; ++i) {
            const d = addDays(start, i)
            const key = dateKeyFor(d)
            result.push({
                key: key,
                label: dayShortNames[d.getDay()],
                value: wordsOn(key),
                typingSeconds: typingSecondsOn(key),
                trackedSeconds: trackedSecondsOn(key),
                isToday: key === todayKey()
            })
        }
        return result
    }

    function analyticsWordsSeries(mode) {
        return seriesWindow(mode).map(function(item) {
            return {
                key: item.key,
                label: item.label,
                value: item.value,
                isToday: item.isToday
            }
        })
    }

    function analyticsTypingSeries(mode) {
        return seriesWindow(mode).map(function(item) {
            return {
                key: item.key,
                label: item.label,
                value: item.typingSeconds,
                isToday: item.isToday
            }
        })
    }

    function analyticsActivitySeries(mode) {
        return seriesWindow(mode).map(function(item) {
            return {
                key: item.key,
                label: item.label,
                typingSeconds: item.typingSeconds,
                idleSeconds: Math.max(0, item.trackedSeconds - item.typingSeconds)
            }
        })
    }

    function analyticsPeriodStats(mode) {
        let start
        let end
        const anchor = new Date(analyticsAnchor)

        if (mode === "month") {
            start = new Date(anchor.getFullYear(), anchor.getMonth(), 1)
            end = new Date(anchor.getFullYear(), anchor.getMonth() + 1, 0)
        } else if (mode === "week") {
            start = startOfWeek(anchor)
            end = endOfWeek(anchor)
        } else {
            start = startOfWeek(anchor)
            end = endOfWeek(anchor)
        }

        const typingSeconds = sumTypingSeconds(start, end)
        const trackedSeconds = sumTrackedSeconds(start, end)
        const idleSeconds = Math.max(0, trackedSeconds - typingSeconds)
        const total = typingSeconds + idleSeconds

        return {
            words: sumWords(start, end),
            typingSeconds: typingSeconds,
            idleSeconds: idleSeconds,
            trackedSeconds: trackedSeconds,
            typingPercent: total > 0 ? typingSeconds / total * 100 : 0,
            idlePercent: total > 0 ? idleSeconds / total * 100 : 0
        }
    }

    function analyticsHeatmapMonth(anchorDate) {
        const anchor = new Date(anchorDate || analyticsAnchor)
        const year = anchor.getFullYear()
        const month = anchor.getMonth()
        const first = new Date(year, month, 1)
        const last = new Date(year, month + 1, 0)

        // Monday-first calendar, matching the analytics UI row labels.
        const mondayOffset = (first.getDay() + 6) % 7
        const gridStart = addDays(first, -mondayOffset)

        const weeks = []
        let maxWords = 0

        for (let w = 0; w < 6; ++w) {
            const week = []
            for (let row = 0; row < 7; ++row) {
                const d = addDays(gridStart, w * 7 + row)
                const key = dateKeyFor(d)
                const inMonth = d.getMonth() === month && d.getFullYear() === year
                const words = inMonth ? wordsOn(key) : 0

                if (inMonth)
                    maxWords = Math.max(maxWords, words)

                week.push({
                    key: key,
                    words: words,
                    inMonth: inMonth,
                    isToday: key === todayKey()
                })
            }
            weeks.push(week)

            if (addDays(gridStart, (w + 1) * 7).getTime() > last.getTime() &&
                w >= 4)
                break
        }

        return {
            monthLabel: monthShortNames[month] + " " + year,
            weeks: weeks,
            maxWords: maxWords
        }
    }

    function analyticsConsistencyStats(mode) {
        const anchor = new Date(analyticsAnchor)
        let start
        let end

        if (mode === "month") {
            start = new Date(anchor.getFullYear(), anchor.getMonth(), 1)
            end = new Date(anchor.getFullYear(), anchor.getMonth() + 1, 0)
        } else if (mode === "week") {
            // Four real calendar weeks ending at selected week.
            end = endOfWeek(anchor)
            start = addDays(startOfWeek(anchor), -21)
        } else {
            start = startOfWeek(anchor)
            end = endOfWeek(anchor)
        }

        let activeDays = 0
        let longestStreak = 0
        let currentStreak = 0
        let totalWords = 0
        let totalDays = 0
        let bestWords = 0
        let bestDate = ""

        for (let d = dayStart(start); d <= end; d = addDays(d, 1)) {
            const key = dateKeyFor(d)
            const words = wordsOn(key)
            totalWords += words
            totalDays += 1

            if (words > 0) {
                ++activeDays
                ++currentStreak
                longestStreak = Math.max(longestStreak, currentStreak)

                if (words > bestWords) {
                    bestWords = words
                    bestDate = key
                }
            } else {
                currentStreak = 0
            }
        }

        return {
            activeDays: activeDays,
            totalDays: totalDays,
            longestStreak: longestStreak,
            dailyAverage: totalDays > 0 ? totalWords / totalDays : 0,
            bestWords: bestWords,
            bestDate: bestDate
        }
    }


    Component.onCompleted: {
        load()
        loadKeyboardDevices()
        inputDeviceReadProc.running = true
        loadAnalytics()
        loadTrackingMode()
    }
}
