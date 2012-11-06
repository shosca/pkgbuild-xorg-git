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

TARGETS=$(addsuffix /built, $(DIRS))

.PHONY: $(DIRS)

all: $(DIRS)

clean:
	find -name '*tar.xz' -exec rm {} \;
	find -name 'built' -exec rm {} \;
	rm -f $(LOCAL)/*-git-* $(LOCAL)/firefox-nightly*

show:
	@echo $(DATE)
	@echo $(TEST)

%/built:
	@rm -f $(addsuffix *, $(addprefix $(LOCAL)/, $(shell grep -R '^pkgname' $*/PKGBUILD | sed -e 's/pkgname=//' -e 's/(//g' -e 's/)//g' -e "s/'//g" -e 's/"//g'))) ; \
	cd $* ; \
		_c=$$(pwd) ;\
		yes "" | makepkg -fsi && rm -rf pkg && \
		_gitname=$$(grep -R '^_gitname' PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') ; \
		if [ -d src/$$_gitname/.git ]; then \
			cd src/$$_gitname ; \
			git log -1 | head -n1 > $$_c/built ; \
		fi \

add:
	cd $(LOCAL)
	rm -rf $(LOCAL)/mine.db*
	repo-add $(LOCAL)/mine.db.tar.gz $(LOCAL)/*.xz

push: add
	rsync -v --recursive --links --times -D --delete \
		$(LOCAL)/ \
		$(REMOTE)/

pull:
	rsync -v --recursive --links --times -D --delete \
		$(REMOTE)/* \
		$(LOCAL)/

$(DIRS):
	@_gitname=$$(grep -R '^_gitname' $@/PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') ; \
	if [ -d $@/src/$$_gitname/.git ]; then \
		cd $@/src/$$_gitname ; \
		git pull ; \
		if [ -f ../../built ] && [ "$$(cat ../../built)" != "$$(git log -1 | head -n1)" ]; then \
			rm ../../built ; \
		fi ; \
		cd ../../.. ; \
	fi ; \
	$(MAKE) $@/built

mesa-git: glproto-git dri2proto-git drm-git llvm-amdgpu-git

glu-git: mesa-git

mesa-demos-git: mesa-git

xorg-server-git: glproto-git dri2proto-git drm-git pixman-git

xf86-input-evdev-git: xorg-server-git

xf86-input-synaptics-git: xorg-server-git

xf86-video-ati-git: xorg-server-git

