# Voxel — original 1-bit 3D games on a shared core.
#
#   make <game>            build games/<game> -> out/<Title>.pdx
#   make <game>-smoke      instrumented build -> out/<Title>Smoke.pdx
#   make all               every game, release builds
#
# No games yet: add lowercase dirs under games/ and list them in GAMES.
# A build stages core/* + games/<g>/* into build/<g>/source (pdc wants one
# source root), writes smokeflag.lua, then runs pdc.

GAMES := rubble crumble lob bulwark herd excavate marble summit vault

OUT := out

define TITLECASE
$(shell echo $(1) | awk '{print toupper(substr($$0,1,1)) substr($$0,2)}')
endef

all: $(GAMES)

define GAME_RULES
$(1): build/$(1)/source
	pdc build/$(1)/source $(OUT)/$(call TITLECASE,$(1)).pdx

$(1)-smoke: build/$(1)-smoke/source
	pdc build/$(1)-smoke/source $(OUT)/$(call TITLECASE,$(1))Smoke.pdx

build/$(1)/source: core/*.lua games/$(1)/*
	mkdir -p $$@ $(OUT)
	cp core/*.lua $$@/
	cp -r games/$(1)/* $$@/
	rm -f $$@/README.md $$@/screenshot.png $$@/*.py
	cp LICENSE $$@/
	echo 'SMOKE_BUILD = false' > $$@/smokeflag.lua

build/$(1)-smoke/source: core/*.lua games/$(1)/*
	mkdir -p $$@ $(OUT)
	cp core/*.lua $$@/
	cp -r games/$(1)/* $$@/
	rm -f $$@/README.md $$@/screenshot.png $$@/*.py
	cp LICENSE $$@/
	echo 'SMOKE_BUILD = true' > $$@/smokeflag.lua

.PHONY: $(1) $(1)-smoke
endef

$(foreach g,$(GAMES),$(eval $(call GAME_RULES,$(g))))

clean:
	rm -rf build $(OUT)

.PHONY: all clean
