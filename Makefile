REPO=xorg-git
LOCAL=~/public_html/arch/$(REPO)
REMOTE=buttercup.local:~/public_html/arch/$(REPO)

PWD=$(shell pwd)
DIRS=$(shell ls | grep 'git')
DATE=$(shell date +"%Y%m%d")
TIME=$(shell date +"%H%M")
PACMAN=yaourt
MAKEPKG=makepkg -sfL
PKGEXT=pkg.tar.xz
GITFETCH=git fetch --all -p
GITCLONE=git clone --mirror

TARGETS=$(addsuffix /built, $(DIRS))

.PHONY: $(DIRS)

all:
	$(MAKE) gitpull
	$(MAKE) build
	$(MAKE) push

push:
	$(MAKE) rebuildrepo
	$(MAKE) pkgpush

pkgpush:
	rsync -v --recursive --links --times -D --delete \
		$(LOCAL)/ \
		$(REMOTE)/

pull:
	rsync -v --recursive --links --times -D --delete \
		$(REMOTE)/ \
		$(LOCAL)/

clean:
	sudo rm -rf */*.log */pkg */src */logpipe*

reset: clean
	sudo rm -f */built $(LOCAL)/*

show:
	@echo $(DATE)
	@echo $(DIRS)

updateversions:
	sed -i "s/^pkgver=[^ ]*/pkgver=$(DATE)/" */PKGBUILD ; \
	sed -i "s/^pkgrel=[^ ]*/pkgrel=$(TIME)/" */PKGBUILD

build: $(DIRS)

test:
	@echo "REPO    : $(REPO)" ; \
	echo "LOCAL   : $(LOCAL)" ; \
	echo "REMOTE  : $(REMOTE)" ; \
	echo "PACMAN  : $(PACMAN)" ; \
	echo "PKGEXT  : $(PKGEXT)" ; \
	echo "GITFETCH: $(GITFETCH)" ; \
	echo "GITCLONE: $(GITCLONE)"

%/built:
	@_gitname=$$(grep -R '^_gitname' $(PWD)/$*/PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') && \
	if [ -f $(PWD)/$*/$$_gitname/HEAD ]; then \
		sed -i "s/^pkgver=[^ ]*/pkgver=$(DATE)/" "$(PWD)/$*/PKGBUILD" ; \
		sed -i "s/^pkgrel=[^ ]*/pkgrel=$(TIME)/" "$(PWD)/$*/PKGBUILD" ; \
	fi ; \
	cd $* ; \
	rm -f *$(PKGEXT) *.log ; \
	yes y$$'\n' | $(MAKEPKG) || exit 1 && \
	yes y$$'\n' | $(PACMAN) -U --force *.$(PKGEXT) ; \
	if [ -f $(PWD)/$*/$$_gitname/HEAD ]; then \
		cd $(PWD)/$*/$$_gitname ; git log -1 | head -n1 > $(PWD)/$*/built ; \
	else \
		touch $(PWD)/$*/built ; \
	fi ; \
	cd $(PWD) ; \
	rm -f $(addsuffix /built, $(shell grep ' $*' Makefile | cut -d':' -f1)) ; \

#	rm -f $(addsuffix *, $(addprefix $(LOCAL)/, $(shell grep -R '^pkgname' $*/PKGBUILD | sed -e 's/pkgname=//' -e 's/(//g' -e 's/)//g' -e "s/'//g" -e 's/"//g'))) ; \

rebuildrepo:
	@cd $(LOCAL) ; \
	rm -f $(LOCAL)/* ; \
	cp $(PWD)/*/*.$(PKGEXT) . ; \
	repo-add -q $(LOCAL)/$(REPO).db.tar.gz $(LOCAL)/*$(PKGEXT)

$(DIRS):
	@if [ ! -f $(PWD)/$@/built ]; then \
		$(MAKE) $@/built ; \
	fi

PULL_TARGETS=$(addsuffix -pull, $(DIRS))

gitpull: $(PULL_TARGETS)

%-pull:
	@_gitroot=$$(grep -R '^_gitroot' $(PWD)/$*/PKGBUILD | sed -e 's/_gitroot=//' -e "s/'//g" -e 's/"//g') && \
	_gitname=$$(grep -R '^_gitname' $(PWD)/$*/PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') && \
	if [ -f $(PWD)/$*/$$_gitname/HEAD ]; then \
		echo "Updating $$_gitname" ; \
		cd $(PWD)/$*/$$_gitname && \
		$(GITFETCH) && \
		if [ -f $(PWD)/$*/built ] && [ "$$(cat $(PWD)/$*/built)" != "$$(git log -1 | head -n1)" ]; then \
			rm -f $(PWD)/$*/built ; \
		fi ; \
		cd $(PWD) ; \
	fi

VER_TARGETS=$(addsuffix -ver, $(DIRS))

vers: $(VER_TARGETS)

%-ver:
	@_gitname=$$(grep -R '^_gitname' $(PWD)/$*/PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') && \
	if [ -d $(PWD)/$*/src/$$_gitname ]; then \
		cd $(PWD)/$*/src/$$_gitname && \
		autoreconf -f > /dev/null 2>&1 && \
		_oldver=$$(grep -R '^_realver' $(PWD)/$*/PKGBUILD | sed -e 's/_realver=//' -e "s/'//g" -e 's/"//g') && \
		_realver=$$(grep 'PACKAGE_VERSION=' configure | head -n1 | sed -e 's/PACKAGE_VERSION=//' -e "s/'//g") ; \
		if [ ! -z $$_realver ] && [ $$_oldver != $$_realver ]; then \
			echo "$(subst -git,,$*) : $$_oldver $$_realver" ; \
			sed -i "s/^_realver=[^ ]*/_realver=$$_realver/" "$(PWD)/$*/PKGBUILD" ; \
			rm -f "$(PWD)/$*/built" ; \
		fi ; \
	fi

bigreqsproto-git: xorg-util-macros-git

compositeproto-git: xorg-util-macros-git

damageproto-git: xorg-util-macros-git

presentproto-git: xorg-util-macros-git

dmxproto-git: xorg-util-macros-git

dri2proto-git: xorg-util-macros-git

dri3proto-git: xorg-util-macros-git

fixesproto-git: xorg-util-macros-git

fontsproto-git: xorg-util-macros-git

glproto-git: xorg-util-macros-git

inputproto-git: xorg-util-macros-git

kbproto-git: xorg-util-macros-git

randrproto-git: xorg-util-macros-git

recordproto-git: xorg-util-macros-git

renderproto-git: xorg-util-macros-git

resourceproto-git: xorg-util-macros-git

scrnsaverproto-git: xorg-util-macros-git

videoproto-git: xorg-util-macros-git

xcb-proto-git: xorg-util-macros-git

xcmiscproto-git: xorg-util-macros-git

xextproto-git: xorg-util-macros-git

xf86dgaproto-git: xorg-util-macros-git

xf86driproto-git: xorg-util-macros-git

xf86vidmodeproto-git: xorg-util-macros-git

xineramaproto-git: xorg-util-macros-git

xproto-git: xorg-util-macros-git

pixman-git: xorg-util-macros-git

wayland-git: xorg-util-macros-git

libpciaccess-git: xorg-util-macros-git

libshmfence-git: xorg-util-macros-git

libdrm-git: libpciaccess-git

libfontenc-git: xproto-git

libxdmcp-git: xproto-git

libxau-git: xproto-git

libxcb-git: xcb-proto-git libxdmcp-git libxau-git

libx11-git: xproto-git kbproto-git xextproto-git xtrans-git inputproto-git libxcb-git

xcb-util-git: xproto-git libxcb-git 

xcb-util-image-git: xcb-util-git

xcb-util-keysyms-git: xcb-util-git

xcb-util-wm-git: xcb-util-git

libxext-git: xextproto-git libx11-git

libxrender-git: renderproto-git libx11-git

libxrandr-git: randrproto-git libxext-git libxrender-git

libxi-git: inputproto-git libxext-git

libxtst-git: recordproto-git inputproto-git libxi-git

libice-git: xproto-git xtrans-git

libsm-git: libice-git xtrans-git xorg-util-macros-git

libxt: libx11-git libsm-git

libxmu-git: libxext-git libxt-git

libxpm-git: libxt-git libxext-git

libxaw-git: libxmu-git libxpm-git

libxres-git: resourceproto-git damageproto-git compositeproto-git scrnsaverproto-git libxext-git

libdmx-git: dmxproto-git libxext-git

libxfixes-git: fixesproto-git libx11-git

libxdamage-git: damageproto-git libxfixes-git

libxcomposite-git: compositeproto-git libxfixes-git

libxxf86vm-git: xf86vidmodeproto-git libxext-git

libxxf86dga-git: xf86dgaproto-git libxext-git

libxv-git: videoproto-git libxext-git

libxvmc-git: libxv-git

libvdpau-git: libx11-git

libva-git: libdrm-git libxfixes-git

libva-intel-driver-git: libva-git

libxcursor-git: libxfixes-git libxrender-git

libxfont-git: xproto-git fontsproto-git libfontenc-git xtrans-git

libxkbfile-git: libx11-git

cairo-git: libxrender-git pixman-git xcb-util-git

libclc-git: llvm-git

mesa-git: glproto-git libdrm-git llvm-git libclc-git libxfixes-git libvdpau-git libxdamage-git libxxf86vm-git libxvmc-git wayland-git

glu-git: mesa-git

mesa-demos-git: mesa-git

xorg-font-util-git: xorg-util-macros-git

xorg-setxkbmap-git: libxkbfile-git xorg-util-macros-git

xorg-server-git: bigreqsproto-git presentproto-git compositeproto-git dmxproto-git dri2proto-git dri3proto-git fontsproto-git glproto-git inputproto-git randrproto-git recordproto-git renderproto-git resourceproto-git scrnsaverproto-git videoproto-git xcmiscproto-git xextproto-git xf86dgaproto-git xf86driproto-git xineramaproto-git libdmx-git libdrm-git libpciaccess-git libx11-git libxau-git libxaw-git libxdmcp-git libxext-git libxfixes-git libxfont-git libxi-git libxkbfile-git libxmu-git libxrender-git libxres-git libxtst-git libxv-git mesa-git pixman-git xkeyboard-config-git xorg-font-util-git xorg-setxkbmap-git xorg-util-macros-git xorg-xkbcomp-git xtrans-git wayland-git xcb-util-image-git xcb-util-wm-git libxshmfence-git

xorg-xauth-git: libxmu-git

xorg-xhost-git: libxmu-git

xorg-xrdb-git: libxmu-git

xorg-xrandr-git: libxrandr-git libx11-git

xorg-xprop-git: libx11-git

xorg-xev-git: libx11-git libxrandr-git xproto-git

xorg-xset-git: libxmu-git xorg-util-macros-git

xorg-mkfontscale-git: libfontenc-git xproto-git

xorg-xwininfo-git: libxcb-git libx11-git

xorg-bdftopcf-git: libxfont-git xproto-git

xorg-xmessage-git: libxaw-git

xorg-fonts-encodings-git: xorg-mkfontscale-git xorg-util-macros-git xorg-font-util-git

xf86-input-evdev-git: xorg-server-git

xf86-input-synaptics-git: xorg-server-git

xf86-video-ati-git: xorg-server-git mesa-git glamor-egl-git libdrm-git libpciaccess-git pixman-git xf86driproto-git glproto-git

radeontop-git:

xf86-video-intel-git: xorg-server-git mesa-git libxvmc-git libpciaccess-git libdrm-git dri2proto-git dri3proto-git libxfixes-git libx11-git xf86driproto-git glproto-git resourceproto-git xcb-util-git glamor-egl-git

xf86-video-nouveau-git: libdrm-git mesa-git xorg-server-git glamor-egl-git

glamor-egl-git: glproto-git xf86driproto-git libx11-git libdrm-git xorg-server-git mesa-git

weston-git: libxkbcommon-git wayland-git mesa-git cairo-git libxcursor-git pixman-git glu-git

lib32-pixman-git: pixman-git

lib32-libxdmcp-git: libxdmcp-git

lib32-libice-git: libice-git

lib32-libxau-git: libxau-git

lib32-libxcb-git: libxcb-git lib32-libxdmcp-git  lib32-libxau-git

lib32-libx11-git: libx11-git lib32-libxcb-git

lib32-libxrender-git: libxrender-git lib32-libx11-git

lib32-libxext-git: libxext-git lib32-libx11-git

lib32-libxv-git: libxv-git lib32-libxext-git

lib32-libxvmc-git: libxvmc-git lib32-libxv-git

lib32-libvdpau-git: libvdpau-git lib32-libx11-git

lib32-libxxf86vm-git: libxxf86vm-git lib32-libxext-git

lib32-libxfixes-git: libxfixes-git lib32-libx11-git

lib32-libxdamage-git: libxdamage-git lib32-libxfixes-git

lib32-libsm-git: libsm-git lib32-libice-git

lib32-libxt-git: libxt-git lib32-libsm-git lib32-libx11-git

lib32-wayland-git: wayland-git

lib32-mesa-git: glproto-git lib32-libxshmfence-git lib32-libdrm-git lib32-llvm-git lib32-libxvmc-git lib32-libvdpau-git lib32-libxxf86vm-git lib32-libxdamage-git lib32-libx11-git lib32-libxt-git lib32-wayland-git mesa-git

lib32-llvm-git: llvm-git

lib32-libdrm-git: libdrm-git

lib32-libxshmfence-git: libxshmfence-git

