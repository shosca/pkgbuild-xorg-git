LOCAL=/home/packages
REMOTE=74.72.157.140:/home/serkan/public_html

DIRS = \
   pacaur-git \
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
   monodevelop-git \
   firefox-nightly \

DATE=$(shell date +"%Y%m%d")

TARGETS=$(addsuffix /built-$(DATE), $(DIRS))

all: $(TARGETS)

clean:
	find -name '*tar.xz' -exec rm {} \;
	find -name 'built-*' -exec rm {} \;
	rm -f $(LOCAL)/*-git-* $(LOCAL)/firefox-nightly*

show:
	@echo $(DATE)
	@echo $(TEST)

%/built-$(DATE):
	@cd $* ; \
		yes "" | makepkg -f && \
		touch built-$(DATE)


$(DIRS):
	@echo "-- $@ --"; cd $@ ; \
	yes "" | makepkg -fsi

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

