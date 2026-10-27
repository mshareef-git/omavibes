#include <fstream>
#include <iostream>
#include <nlohmann/json.hpp>
#include <string>
#include <unordered_map>

using json = nlohmann::json;

namespace {

// Translation table from Mechvibes / libuiohook virtual keycodes to Linux evdev keycodes
const std::unordered_map<int, int> uiohookToEvdev = {
    // Windows / Meta keys
    {3675, 125}, // KEY_LEFTMETA (Super_L)
    {3676, 126}, // KEY_RIGHTMETA (Super_R)
    {3677, 127}, // KEY_COMPOSE (Menu)

    // Editing & Navigation keys
    {3667, 111}, // KEY_DELETE
    {3666, 110}, // KEY_INSERT
    {3655, 102}, // KEY_HOME
    {3663, 107}, // KEY_END
    {3657, 104}, // KEY_PAGEUP
    {3665, 109}, // KEY_PAGEDOWN

    // Cursor / Arrow keys
    {57416, 103}, // KEY_UP
    {57424, 108}, // KEY_DOWN
    {57419, 105}, // KEY_LEFT
    {57421, 106}, // KEY_RIGHT

    // Modifiers & special
    {3613, 97},  // KEY_RIGHTCTRL
    {3640, 100}, // KEY_RIGHTALT
    {3612, 96},  // KEY_KPENTER
    {3637, 98},  // KEY_KPSLASH
    {3639, 99},  // KEY_SYSRQ / PrintScreen
    {3653, 119}, // KEY_PAUSE
    {3597, 140}, // KEY_CALC

    // Numpad navigation variants (when NumLock is off or shifted)
    {60999, 102}, // KEY_HOME
    {61000, 103}, // KEY_UP
    {61001, 104}, // KEY_PAGEUP
    {61003, 105}, // KEY_LEFT
    {61005, 106}, // KEY_RIGHT
    {61007, 107}, // KEY_END
    {61008, 108}, // KEY_DOWN
    {61009, 109}, // KEY_PAGEDOWN
    {61010, 110}, // KEY_INSERT
    {61011, 111}, // KEY_DELETE
};

} // namespace

std::unordered_map<int, std::string> loadKeySoundMappings(const std::string &configPath) {
  std::unordered_map<int, std::string> keySoundMap;

  std::ifstream configFile(configPath);
  if (!configFile.is_open()) {
    std::cerr << "Could not open config.json file! Is the soundpack path correct?"
              << std::endl;
    exit(1);
    return keySoundMap;
  }

  try {
    json configJson;
    configFile >> configJson;

    if (configJson.contains("defines")) {
      for (auto &[key, value] : configJson["defines"].items()) {
        int keyCode = std::stoi(key);
        if (!value.is_null()) {
          std::string soundFile = value.get<std::string>();
          keySoundMap[keyCode] = soundFile;

          // If this key is a Mechvibes/uiohook keycode, also map its Linux evdev equivalent
          auto it = uiohookToEvdev.find(keyCode);
          if (it != uiohookToEvdev.end()) {
            if (keySoundMap.find(it->second) == keySoundMap.end()) {
              keySoundMap[it->second] = soundFile;
            }
          }
        }
      }
    }

    // Common key fallbacks if missing:
    // Super_R falls back to Super_L
    if (keySoundMap.find(125) != keySoundMap.end() && keySoundMap.find(126) == keySoundMap.end()) {
      keySoundMap[126] = keySoundMap[125];
    }
    // Delete falls back to Backspace (14) if not defined
    if (keySoundMap.find(14) != keySoundMap.end() && keySoundMap.find(111) == keySoundMap.end()) {
      keySoundMap[111] = keySoundMap[14];
    }
    // Insert falls back to Delete or Backspace
    if (keySoundMap.find(111) != keySoundMap.end() && keySoundMap.find(110) == keySoundMap.end()) {
      keySoundMap[110] = keySoundMap[111];
    }
  } catch (json::exception &e) {
    std::cerr << "Error parsing config.json: " << e.what() << std::endl;
  }

  return keySoundMap;
}
