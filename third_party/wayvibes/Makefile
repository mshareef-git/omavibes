TARGET = wayvibes

SRC = src/main.cpp src/audio.cpp src/device.cpp src/config.cpp src/analytics.cpp src/secure_file.cpp
INC = -Isrc
CXXFLAGS = -std=c++17 -O3 -march=native $(INC)
LIBS = -levdev

all: $(TARGET)

$(TARGET): $(SRC) src/miniaudio.h
	g++ $(CXXFLAGS) -o $(TARGET) $(SRC) $(LIBS)

install: $(TARGET)
	install -Dm755 $(TARGET) -t /usr/local/bin

uninstall:
	rm -f /usr/local/bin/$(TARGET)

clean:
	rm -f $(TARGET)

.PHONY: all install clean uninstall
