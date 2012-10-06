DIRS = \
	   pacaur-git \
	   glproto-git \
	   pixman-git \
	   drm-git \
	   mesa-git \
	   xorg-server-git \
	   cairo-git \
	   libglu-git \
	   xf86-video-ati-git \
	   xf86-input-evdev-git \
	   monodevelop-git \


.PHONY: $(DIRS)
all: $(DIRS)

$(DIRS):
	@echo "-- $@ --"; cd $@ ; \
	yes "" | makepkg -fsic

xf86-video-ati-git: xorg-server-git

xf86-video-evdev-git: drm-git mesa-git xorg-server-git
