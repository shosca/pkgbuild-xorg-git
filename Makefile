REPO=xorg-git
PWD=$(shell pwd)
DIRS=$(shell ls -d */ | sed -e 's/\///' )
ARCHNSPAWN=arch-nspawn
MKARCHROOT=/usr/bin/mkarchroot -C /usr/share/devtools/pacman-multilib.conf
MAKECHROOTPKG=/usr/bin/makechrootpkg -c -u -r
PKGEXT=pkg.tar.xz
GITFETCH=git fetch --all -p
GITCLONE=git clone --mirror
CHROOTPATH64=/tmp/chroot64/$(REPO)

TARGETS=$(addsuffix /built, $(DIRS))
PULL_TARGETS=$(addsuffix -pull, $(DIRS))
VER_TARGETS=$(addsuffix -ver, $(DIRS))
SHA_TARGETS=$(addsuffix -sha, $(DIRS))

.PHONY: $(DIRS) checkchroot

all:
	$(MAKE) gitpull
	$(MAKE) build

clean:
	sudo rm -rf */*.log */pkg */src */logpipe*

reset: clean
	sudo rm -f */built

checkchroot:
	@if [ ! -d $(CHROOTPATH64) ]; then \
		echo "Creating working chroot at $(CHROOTPATH64)/root" ; \
		sudo mkdir -p $(CHROOTPATH64) ;\
		[[ ! -f $(CHROOTPATH64)/root/.arch-chroot ]] && sudo $(MKARCHROOT) $(CHROOTPATH64)/root base-devel ; \
		sudo sed -i -e '/^#\[multilib\]/ s,#,,' \
			-i -e '/^\[multilib\]/{$$!N; s,#,,}' $(CHROOTPATH64)/root/etc/pacman.conf ; \
		sudo mkdir -p $(CHROOTPATH64)/root/repo ;\
		echo "# Added by $$PKG" | sudo tee -a $(CHROOTPATH64)/root/etc/pacman.conf ; \
		echo "[$(REPO)]" | sudo tee -a $(CHROOTPATH64)/root/etc/pacman.conf ; \
		echo "SigLevel = Never" | sudo tee -a $(CHROOTPATH64)/root/etc/pacman.conf ; \
		echo "Server = file:///repo" | sudo tee -a $(CHROOTPATH64)/root/etc/pacman.conf ; \
		echo "COMPRESSXZ=(7z a dummy -txz -si -so)" | sudo tee -a $(CHROOTPATH64)/root/etc/makepkg.conf ; \
		$(MAKE) recreaterepo ; \
		sudo $(ARCHNSPAWN) $(CHROOTPATH64)/root pacman \
			-Syyu --noconfirm ; \
		sudo $(ARCHNSPAWN) $(CHROOTPATH64)/root \
			/bin/bash -c 'yes | pacman -S gcc-multilib gcc-libs-multilib p7zip' ; \
	fi

resetchroot:
	sudo rm -rf $(CHROOTPATH64) && $(MAKE) checkchroot

recreaterepo:
	echo "Recreating working repo $(REPO)" ; \
	if ls */*.$(PKGEXT) &> /dev/null ; then \
		sudo cp -f */*.$(PKGEXT) $(CHROOTPATH64)/root/repo ; \
		sudo repo-add $(CHROOTPATH64)/root/repo/$(REPO).db.tar.gz $(CHROOTPATH64)/root/repo/*.$(PKGEXT) ; \
	fi ; \

build: $(DIRS)

test:
	@echo "REPO    : $(REPO)" ; \
	echo "DIRS    : $(DIRS)" ; \
	echo "PKGEXT  : $(PKGEXT)" ; \
	echo "GITFETCH: $(GITFETCH)" ; \
	echo "GITCLONE: $(GITCLONE)"

%/built:
	@_gitname=$$(grep -R '^_gitname' $(PWD)/$*/PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') && \
	cd $* ; \
	rm -f *$(PKGEXT) *.log ; \
	sudo $(MAKECHROOTPKG) $(CHROOTPATH64) || exit 1 && \
	sudo rm -f $(addsuffix *, $(addprefix $(CHROOTPATH64)/root/repo/, $(shell grep -R '^pkgname' $*/PKGBUILD | sed -e 's/pkgname=//' -e 's/(//g' -e 's/)//g' -e "s/'//g" -e 's/"//g'))) ; \
	sudo cp *.$(PKGEXT) $(CHROOTPATH64)/root/repo/ && \
	for f in *.$(PKGEXT) ; do \
		sudo repo-add $(CHROOTPATH64)/root/repo/$(REPO).db.tar.gz $(CHROOTPATH64)/root/repo/"$$f" ; \
	done ; \
	if [ -f $(PWD)/$*/$$_gitname/HEAD ]; then \
		cd $(PWD)/$*/$$_gitname ; git log -1 | head -n1 > $(PWD)/$*/built ; \
	else \
		touch $(PWD)/$*/built ; \
	fi ; \
	cd $(PWD) ; \
	rm -f $(addsuffix /built, $(shell grep ' $*' Makefile | cut -d':' -f1)) ; \

$(DIRS): checkchroot
	@if [ ! -f $(PWD)/$@/built ]; then \
		_pkgrel=$$(grep -R '^pkgrel' $(PWD)/$@/PKGBUILD | sed -e 's/pkgrel=//' -e "s/'//g" -e 's/"//g') && \
		sed --follow-symlinks -i "s/^pkgrel=[^ ]*/pkgrel=$$(($$_pkgrel+1))/" $(PWD)/$@/PKGBUILD ; \
		$(MAKE) $@/built ; \
	fi

gitpull: $(PULL_TARGETS)

%-pull:
	@_gitroot=$$(grep -R '^_gitroot' $(PWD)/$*/PKGBUILD | sed -e 's/_gitroot=//' -e "s/'//g" -e 's/"//g') && \
	_gitname=$$(grep -R '^_gitname' $(PWD)/$*/PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') && \
	echo "Pulling $*" ; \
	if [ -f $(PWD)/$*/$$_gitname/HEAD ]; then \
		echo "Updating $$_gitname" ; \
		cd $(PWD)/$*/$$_gitname && \
		$(GITFETCH) && \
		if [ -f $(PWD)/$*/built ] && [ "$$(cat $(PWD)/$*/built)" != "$$(git log -1 | head -n1)" ]; then \
			rm -f $(PWD)/$*/built ; \
			_newpkgver="r$$(git --git-dir=$(PWD)/$*/$$_gitname rev-list --count HEAD).$$(git --git-dir=$(PWD)/$*/$$_gitname rev-parse --short HEAD)" ; \
			sed --follow-symlinks -i "s/^pkgver=[^ ]*/pkgver=$$_newpkgver/" $(PWD)/$*/PKGBUILD ; \
			sed --follow-symlinks -i "s/^pkgrel=[^ ]*/pkgrel=0/" $(PWD)/$*/PKGBUILD ; \
		fi ; \
		cd $(PWD) ; \
	fi

vers: $(VER_TARGETS)

%-ver:
	@_gitname=$$(grep -R '^_gitname' $(PWD)/$*/PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') && \
	if [ -d $(PWD)/$*/$$_gitname ]; then \
		_newpkgver="r$$(git --git-dir=$(PWD)/$*/$$_gitname rev-list --count HEAD).$$(git --git-dir=$(PWD)/$*/$$_gitname rev-parse --short HEAD)" ; \
		sed --follow-symlinks -i "s/^pkgver=[^ ]*/pkgver=$$_newpkgver/" $(PWD)/$*/PKGBUILD ; \
		echo "$* r$$(git --git-dir=$(PWD)/$*/$$_gitname rev-list --count HEAD).$$(git --git-dir=$(PWD)/$*/$$_gitname rev-parse --short HEAD)" ; \
	fi

updateshas: $(SHA_TARGETS)

%-sha:
	@cd $(PWD)/$* && updpkgsums

-include Makefile.mk

libomxil-bellagio-git:

xorg-util-macros-git:

bigreqsproto-git: xorg-util-macros-git

compositeproto-git: xorg-util-macros-git

damageproto-git: xorg-util-macros-git

presentproto-git: xorg-util-macros-git

dmxproto-git: xorg-util-macros-git

dri2proto-git: xorg-util-macros-git

dri3proto-git: xorg-util-macros-git

fixesproto-git: xorg-util-macros-git xproto-git xextproto-git

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

libfontenc-git: xproto-git xorg-font-util-git

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

libxt-git: libx11-git libsm-git

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

libvdpau-git: libx11-git libxext-git

vdpauinfo-git: libvdpau-git

libva-git: libdrm-git libxfixes-git

libva-intel-driver-git: libva-git

libxcursor-git: libxfixes-git libxrender-git

libxfont-git: xproto-git fontsproto-git libfontenc-git xtrans-git

libxkbfile-git: libx11-git

cairo-git: libxrender-git pixman-git xcb-util-git mesa-git

libclc-git: llvm-git

libepoxy-git: mesa-git xorg-util-macros-git

mesa-git: glproto-git libdrm-git llvm-git libclc-git libxfixes-git libvdpau-git libxdamage-git libxxf86vm-git libxvmc-git wayland-git libomxil-bellagio-git libxshmfence-git dri2proto-git dri3proto-git presentproto-git

glu-git: mesa-git

glew-git: glu-git

mesa-demos-git: mesa-git glew-git

xorg-font-util-git: xorg-util-macros-git

xorg-setxkbmap-git: libxkbfile-git xorg-util-macros-git

xorg-server-git: bigreqsproto-git presentproto-git compositeproto-git dmxproto-git dri2proto-git dri3proto-git fontsproto-git glproto-git inputproto-git randrproto-git recordproto-git renderproto-git resourceproto-git scrnsaverproto-git videoproto-git xcmiscproto-git xextproto-git xf86dgaproto-git xf86driproto-git xineramaproto-git libdmx-git libdrm-git libpciaccess-git libx11-git libxau-git libxaw-git libxdmcp-git libxext-git libxfixes-git libxfont-git libxi-git libxkbfile-git libxmu-git libxrender-git libxres-git libxtst-git libxv-git libepoxy-git mesa-git pixman-git xkeyboard-config-git xorg-font-util-git xorg-setxkbmap-git xorg-util-macros-git xorg-xkbcomp-git xtrans-git wayland-git xcb-util-image-git xcb-util-wm-git xcb-util-keysyms-git libxshmfence-git

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

xf86-input-evdev-git: xorg-server-git libevdev-git libxi-git libxtst-git resourceproto-git scrnsaverproto-git

xf86-input-synaptics-git: xorg-server-git libevdev-git libxi-git libxtst-git resourceproto-git scrnsaverproto-git

xf86-video-ati-git: xorg-server-git mesa-git libdrm-git libpciaccess-git pixman-git xf86driproto-git glproto-git

radeontop-git:

xkeyboard-config-git: kbproto-git xcb-proto-git xproto-git libx11-git libxau-git libxcb-git libxdmcp-git libxkbfile-git xorg-xkbcomp-git

xf86-video-intel-git: xorg-server-git mesa-git libxvmc-git libpciaccess-git libdrm-git dri2proto-git dri3proto-git libxfixes-git libx11-git xf86driproto-git glproto-git resourceproto-git xcb-util-git

xf86-video-nouveau-git: libdrm-git mesa-git xorg-server-git

weston-git: libinput-git libxkbcommon-git wayland-git mesa-git cairo-git libxcursor-git pixman-git glu-git

lib32-libpciaccess-git:

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

lib32-libdrm-git: libdrm-git lib32-libpciaccess-git

lib32-mesa-git: glproto-git lib32-libxshmfence-git lib32-libdrm-git lib32-llvm-git lib32-libxvmc-git lib32-libvdpau-git lib32-libxxf86vm-git lib32-libxdamage-git lib32-libx11-git lib32-libxt-git lib32-wayland-git mesa-git lib32-libxshmfence-git

lib32-llvm-git: llvm-git

lib32-libxshmfence-git: libxshmfence-git

