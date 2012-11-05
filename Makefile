LOCAL=/home/packages
REMOTE=74.72.157.140:/home/serkan/public_html

DIRS = \
   pacaur-git \
   llvm-amdgpu-git \
   glproto-git \
   dri2proto-git \
   pixman-git \
   drm-git \
   mesa-git \
   xorg-server-git \
   cairo-git \
   glu-git \
   xf86-video-ati-git \
   xf86-input-evdev-git \
   xf86-input-synaptics-git \
   mesa-demos-git \
   monodevelop-git \
   firefox-nightly \

DATE=$(shell date +"%Y%m%d")

TARGETS=$(addsuffix /built-$(DATE), $(DIRS))

.PHONY: $(DIRS)

all: $(DIRS)

clean:
	find -name '*tar.xz' -exec rm {} \;
	find -name 'built-*' -exec rm {} \;
	rm -f $(LOCAL)/*-git-* $(LOCAL)/firefox-nightly*

show:
	@echo $(DATE)
	@echo $(TEST)

%: %/built-$(DATE)

%/built-$(DATE):
	@cd $* ; \
		yes "" | makepkg -fsi && \
		touch built-$(DATE) && \
		rm -rf pkg


$(DIRS):
	@$(MAKE) $@/built-$(DATE)

add:
	@cd $(LOCAL)
	@rm -rf $(LOCAL)/mine.db*
	@repo-add $(LOCAL)/mine.db.tar.gz $(LOCAL)/*.xz

push: add
	@rsync -v --recursive --links --times -D --delete \
		$(LOCAL)/ \
		$(REMOTE)/

pull:
	@rsync -v --recursive --links --times -D --delete \
		$(REMOTE)/* \
		$(LOCAL)/

mesa-git: glproto-git dri2proto-git drm-git llvm-amdgpu-git

glu-git: mesa-git

mesa-demos-git: mesa-git

xorg-server-git: glproto-git dri2proto-git drm-git pixman-git

xf86-input-evdev-git: xorg-server-git

xf86-input-synaptics-git: xorg-server-git

xf86-video-ati-git: xorg-server-git

