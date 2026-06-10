UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
    OS := linux
endif
ifeq ($(UNAME_S),Darwin)
    OS := macosx
endif

# Default configuration is debug
CONFIG ?= debug

.PHONY: all clean

all:
	./premake/$(OS)/premake5 gmake
	$(MAKE) -C build/$(OS)/gmake config=$(CONFIG)

clean:
	if [ -d "build/$(OS)/gmake" ]; then $(MAKE) -C build/$(OS)/gmake clean; fi
	rm -f libotp_pony_node_c.so
