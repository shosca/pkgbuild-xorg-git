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
	   xf86-input-synaptics-git \
	   monodevelop-git \
	   muffin-git \
	   cinnamon-git \
	   nemo-git \
	   nemo-fileroller-git \
	   nemo-dropbox-git \


.PHONY: $(DIRS)
all: $(DIRS)

clean:
	find -name '*tar.xz' -exec rm {} \;

$(DIRS):
	@echo "-- $@ --"; cd $@ ; \
	yes "" | makepkg -fsi

xorg-server-git: glproto-git

mesa-git: glproto-git

xf86-video-ati-git: drm-git xorg-server-git

xf86-video-evdev-git: drm-git mesa-git xorg-server-git

xf86-video-synaptics-git: mesa-git xorg-server-git

libglu-git: mesa-git

cinnamon-git: muffin-git
