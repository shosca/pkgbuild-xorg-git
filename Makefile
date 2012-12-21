LOCAL=/home/packages
REMOTE=74.72.157.140:/home/serkan/public_html/arch

PWD=$(shell pwd)
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

test:
	_gitname=$$(grep -R '^_gitname' $(PWD)/$*/PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') && \
	echo $$_gitname

%/built:
	@rm -f $(addsuffix *, $(addprefix $(LOCAL)/, $(shell grep -R '^pkgname' $*/PKGBUILD | sed -e 's/pkgname=//' -e 's/(//g' -e 's/)//g' -e "s/'//g" -e 's/"//g'))) ; \
	rm -f $(addsuffix /built, $(shell grep $* Makefile | cut -d':' -f1)) ; \
	_gitname=$$(grep -R '^_gitname' $(PWD)/$*/PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') && \
	if [ -d $(PWD)/$*/src/$$_gitname/.git ]; then \
		sed -i "s/^pkgrel=[^ ]*/pkgrel=$$(git whatchanged --since=yesterday | grep $*/PKGBUILD | wc -l)/" "$(PWD)/$*/PKGBUILD" ; \
	fi ; \
	rm -f $(PWD)/$*/*.xz ; \
	cd $* ; yes "" | makepkg -fs && cd $(PWD) ; \
	if [ -d $(PWD)/$*/src/$$_gitname/.git ]; then \
		cd $(PWD)/$*/src/$$_gitname && \
		git log -1 | head -n1 > $(PWD)/$*/built ; \
	else \
		touch $(PWD)/$*/built ; \
	fi ; \
	cd $(PWD) ; yes "" | sudo pacman -U $*/*.xz

add:
	cd $(LOCAL)
	rm -rf $(LOCAL)/mine.db*
	repo-add $(LOCAL)/mine.db.tar.gz $(LOCAL)/*.xz

$(DIRS):
	@_gitroot=$$(grep -R '^_gitroot' $(PWD)/$@/PKGBUILD | sed -e 's/_gitroot=//' -e "s/'//g" -e 's/"//g') && \
	_gitname=$$(grep -R '^_gitname' $(PWD)/$@/PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') && \
	if [ -z $$_gitroot ]; then \
		$(MAKE) $@/built ; \
	else \
		if [ -d $(PWD)/$@/src/$$_gitname/.git ]; then \
			echo "Updating $$_gitname" ; \
			cd $(PWD)/$@/src/$$_gitname && \
			git checkout -f && git pull && \
			if [ -f $(PWD)/$@/built ] && [ "$$(cat $(PWD)/$@/built)" != "$$(git log -1 | head -n1)" ]; then \
				rm -f $(PWD)/$@/built ; \
			fi ; \
			cd $(PWD) ; \
		else \
			echo "Cloning $$_gitroot to $@/src/$$_gitname" ; \
			git clone --depth 1 $$_gitroot $(PWD)/$@/src/$$_gitname ; \
		fi ; \
		$(MAKE) $@/built ; \
	fi ; \

mesa-git: glproto-git dri2proto-git libdrm-git llvm-amdgpu-git wayland-git

lib32-mesa-git: glproto-git dri2proto-git lib32-libdrm-git lib32-llvm-amdgpu-git lib32-wayland-git

wayland-git: libdrm-git

lib32-wayland-git: lib32-libdrm-git

weston-git: mesa-git libxkbcommon-git pixman-git

glu-git: mesa-git

mesa-demos-git: mesa-git

xorg-server-git: glproto-git dri2proto-git inputproto-git libdrm-git pixman-git

xf86-input-evdev-git: xorg-server-git

xf86-input-synaptics-git: xorg-server-git

xf86-video-ati-git: xorg-server-git glamor-git

glamor-git: xorg-server-git mesa-git

spice: spice-protocol

qemu-kvm: spice

cinnamon-git: muffin-git

monodevelop-git: mono-git xsp-git

xsp-git: mono-git

fsharp-git: mono-git

lightdm: pantheon-greeter

pantheon-greeter: granite-bzr libindicator3
