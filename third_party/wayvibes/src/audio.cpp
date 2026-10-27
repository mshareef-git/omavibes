#define MINIAUDIO_IMPLEMENTATION

#include "audio.h"
#include "analytics.h"

#include <fcntl.h>
#include <poll.h>
#include <iostream>
#include <linux/input.h>
#include <unistd.h>

#include <chrono>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

ma_engine engine;

ma_result initializeAudioEngine() {
  ma_engine_config config = ma_engine_config_init();
  config.periodSizeInFrames = 64; // Ultra-low latency: ~1.33ms buffer at 48kHz
  return ma_engine_init(&config, &engine);
}

void uninitializeAudioEngine() {
  ma_engine_uninit(&engine);
}

void playSound(const std::string &soundFile) {
  if (ma_engine_play_sound(&engine, soundFile.c_str(), NULL) != MA_SUCCESS) {
    std::cerr << "Error playing sound: " << soundFile << std::endl;
  }
}

void setVolume(float volume) {
  ma_engine_set_volume(&engine, volume);
}

namespace {

struct SoundVoicePool {
  static constexpr size_t POOL_SIZE = 4;
  ma_sound voices[POOL_SIZE];
  size_t voiceCount = 0;
  size_t nextVoice = 0;

  void play() {
    if (voiceCount == 0) return;
    ma_sound *s = &voices[nextVoice];
    nextVoice = (nextVoice + 1) % voiceCount;
    ma_sound_seek_to_pcm_frame(s, 0);
    ma_sound_start(s);
  }

  void uninit() {
    for (size_t i = 0; i < voiceCount; ++i) {
      ma_sound_uninit(&voices[i]);
    }
    voiceCount = 0;
  }
};

} // namespace

void runMainLoop(
    const std::string &devicePath,
    const std::unordered_map<int, std::string> &keySoundMap,
    float volume,
    const std::string &soundpackPath,
    bool analyticsOnly,
    bool analyticsEnabled) {

  int fd = open(devicePath.c_str(), O_RDONLY | O_NONBLOCK);

  if (fd < 0) {
    std::cerr << "Failed to open input device: " << devicePath << std::endl;
    return;
  }

  std::unordered_map<std::string, std::unique_ptr<SoundVoicePool>> soundPools;
  std::vector<SoundVoicePool*> keyToPool(1024, nullptr);
  SoundVoicePool *defaultPool = nullptr;

  if (!analyticsOnly) {
    setVolume(volume);
    std::cout << "Listening for key events on: " << devicePath << std::endl;

    // Preload and pre-decode all unique sound clips into RAM
    for (const auto &[code, filename] : keySoundMap) {
      if (filename.empty()) continue;
      if (soundPools.find(filename) == soundPools.end()) {
        const std::string fullPath = (soundpackPath.empty() || soundpackPath.back() == '/')
                                         ? soundpackPath + filename
                                         : soundpackPath + "/" + filename;
        auto pool = std::make_unique<SoundVoicePool>();

        ma_result res = ma_sound_init_from_file(
            &engine,
            fullPath.c_str(),
            MA_SOUND_FLAG_DECODE | MA_SOUND_FLAG_NO_SPATIALIZATION | MA_SOUND_FLAG_NO_PITCH,
            NULL,
            NULL,
            &pool->voices[0]);

        if (res == MA_SUCCESS) {
          pool->voiceCount = 1;
          // Pre-clone voices for polyphony so fast repeats don't cut off or allocate
          for (size_t i = 1; i < SoundVoicePool::POOL_SIZE; ++i) {
            ma_result copyRes = ma_sound_init_copy(
                &engine,
                &pool->voices[0],
                MA_SOUND_FLAG_NO_SPATIALIZATION | MA_SOUND_FLAG_NO_PITCH,
                NULL,
                &pool->voices[i]);
            if (copyRes == MA_SUCCESS) {
              pool->voiceCount++;
            }
          }
          soundPools[filename] = std::move(pool);
        } else {
          std::cerr << "Warning: Failed to preload sound file: " << fullPath << std::endl;
          soundPools[filename] = nullptr;
        }
      }
    }

    // Populate direct O(1) lookup table
    for (const auto &[code, filename] : keySoundMap) {
      if (code >= 0 && static_cast<size_t>(code) < keyToPool.size()) {
        auto it = soundPools.find(filename);
        if (it != soundPools.end() && it->second) {
          keyToPool[code] = it->second.get();
        }
      }
    }

    // Find a default fallback pool for any keys not explicitly defined in the soundpack
    const int candidateFallbacks[] = {57, 28, 30, 42, 14, 15}; // Space, Enter, A, LeftShift, Backspace, Tab
    for (int cand : candidateFallbacks) {
      if (cand < (int)keyToPool.size() && keyToPool[cand] != nullptr) {
        defaultPool = keyToPool[cand];
        break;
      }
    }
    if (!defaultPool) {
      for (const auto &pair : soundPools) {
        if (pair.second && pair.second->voiceCount > 0) {
          defaultPool = pair.second.get();
          break;
        }
      }
    }
  }

  AnalyticsTracker analytics;
  analytics.setEnabled(analyticsEnabled);

  struct pollfd pfd{};
  pfd.fd = fd;
  pfd.events = POLLIN;

  auto lastFlush = std::chrono::steady_clock::now();

  while (true) {
    int ret = poll(&pfd, 1, 1000);

    if (ret > 0 && (pfd.revents & POLLIN)) {
      struct input_event ev{};
      while (read(fd, &ev, sizeof(ev)) == static_cast<ssize_t>(sizeof(ev))) {
        if (ev.type == EV_KEY && ev.value == 1) {
          // Play sound FIRST for lowest possible latency!
          if (!analyticsOnly) {
            SoundVoicePool *pool = nullptr;
            if (static_cast<size_t>(ev.code) < keyToPool.size()) {
              pool = keyToPool[ev.code];
            }
            if (!pool) {
              pool = defaultPool;
            }
            if (pool) {
              pool->play();
            }
          }

          if (analyticsEnabled) {
            analytics.recordKeyPress(static_cast<unsigned int>(ev.code));
          }
        }
      }
    }

    if (analyticsEnabled) {
      const auto now = std::chrono::steady_clock::now();

      if (now - lastFlush >= std::chrono::seconds(5)) {
        analytics.flush();
        lastFlush = now;
      }
    }
  }

  for (auto &pair : soundPools) {
    if (pair.second) {
      pair.second->uninit();
    }
  }

  analytics.shutdown();
  close(fd);
}
