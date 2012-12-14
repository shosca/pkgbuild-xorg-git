LOCAL=/home/packages
REMOTE=74.72.157.140:/home/serkan/public_html/arch

DIRS=$(shell ls | grep -v Makefile)
DATE=$(shell date +"%Y-%m-%d")

TARGETS=$(addsuffix /built, $(DIRS))

.PHONY: $(DIRS)

all:
	$(MAKE) pull
	$(MAKE) build
	$(MAKE) add
	$(MAKE) push

push:
	rsync -v --recursive --links --times -D --delete \
		$(LOCAL)/ \
		$(REMOTE)/

pull:
	rsync -v --recursive --links --times -D --delete \
		$(REMOTE)/ \
		$(LOCAL)/

clean:
	find -name '*tar.xz' -exec rm {} \;

realclean: clean
	find -name 'built' -exec rm {} \;

show:
	@echo $(DATE)
	@echo $(DIRS)

build: $(DIRS)

%/built:
	@rm -f $(addsuffix *, $(addprefix $(LOCAL)/, $(shell grep -R '^pkgname' $*/PKGBUILD | sed -e 's/pkgname=//' -e 's/(//g' -e 's/)//g' -e "s/'//g" -e 's/"//g'))) ; \
	rm -f $(addsuffix /built, $(shell grep $* Makefile | cut -d':' -f1)) ; \
	cd $* ; \
		rm -f *.xz ; \
		_c=$$(pwd) ;\
		_gitname=$$(grep -R '^_gitname' PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') && \
		yes "" | makepkg -fs && rm -rf pkg && \
		if [ -d src/$$_gitname/.git ]; then \
			cd src/$$_gitname && \
			git log -1 | head -n1 > $$_c/built ; \
		else \
			touch $$_c/built ; \
		fi && \
		yes "" | sudo pacman -U $$_c/*.xz

add:
	cd $(LOCAL)
	rm -rf $(LOCAL)/mine.db*
	repo-add $(LOCAL)/mine.db.tar.gz $(LOCAL)/*.xz

$(DIRS):
	@echo $@ ; _gitname=$$(grep -R '^_gitname' $@/PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') ; \
	if [ -d $@/src/$$_gitname/.git ]; then \
		sed -i "s/^pkgrel=[^ ]*/pkgrel=$$(git whatchanged --since=yesterday | grep $@/PKGBUILD | wc -l)/" "$@/PKGBUILD" && \
		cd $@/src/$$_gitname && \
		git checkout -f && git clean -xfd && git pull && \
		if [ -f ../../built ] && [ "$$(cat ../../built)" != "$$(git log -1 | head -n1)" ]; then \
			rm -f ../../built ; \
		fi ; \
		cd ../../.. ; \
	fi ; \
	$(MAKE) $@/built

mesa-git: glproto-git dri2proto-git drm-git llvm-amdgpu-git wayland-git

wayland-git: drm-git

weston-git: mesa-git libxkbcommon-git pixman-git

glu-git: mesa-git

mesa-demos-git: mesa-git

xorg-server-git: glproto-git dri2proto-git drm-git pixman-git

xf86-input-evdev-git: xorg-server-git

xf86-input-synaptics-git: xorg-server-git

xf86-video-ati-git: xorg-server-git glamor-git

glamor-git: xorg-server-git mesa-git

spice: spice-protocol

qemu-kvm: spice

cinnamon-git: muffin-git

monodevelop-git: mono-git xsp-git

xsp-git: mono-git
