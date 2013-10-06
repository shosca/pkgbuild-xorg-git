REPO=xorg-git
LOCAL=/home/serkan/public_html/arch/$(REPO)
REMOTE=buttercup.local:/home/serkan/public_html/arch/$(REPO)

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
	$(MAKE) pull
	$(MAKE) build
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
	find -name '*$(PKGEXT)' -exec rm {} \;
	find -name 'built' -exec rm {} \;
	rm -f */*.log $(LOCAL)/*$(PKGEXT)

show:
	@echo $(DATE)
	@echo $(DIRS)

updateversions:
	sed -i "s/^pkgver=[^ ]*/pkgver=$(DATE)/" */PKGBUILD ; \
	sed -i "s/^pkgrel=[^ ]*/pkgrel=$(TIME)/" */PKGBUILD

build: $(DIRS)

test:
	_gitname=$$(grep -R '^_gitname' $(PWD)/$*/PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') && \
	echo $$_gitname

%/built:
	@_gitname=$$(grep -R '^_gitname' $(PWD)/$*/PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') && \
	if [ -f $(PWD)/$*/$$_gitname/HEAD ]; then \
		sed -i "s/^pkgver=[^ ]*/pkgver=$(DATE)/" "$(PWD)/$*/PKGBUILD" ; \
		sed -i "s/^pkgrel=[^ ]*/pkgrel=$(TIME)/" "$(PWD)/$*/PKGBUILD" ; \
	fi ; \
	rm -f $(PWD)/$*/*$(PKGEXT) $(PWD)/$*/*.log ; \
	cd $* ; yes y$$'\n' | $(MAKEPKG) || exit 1 && \
	yes y$$'\n' | $(PACMAN) -U --force *$(PKGEXT) && \
	cd $(PWD) && \
	rm -f $(addsuffix *, $(addprefix $(LOCAL)/, $(shell grep -R '^pkgname' $*/PKGBUILD | sed -e 's/pkgname=//' -e 's/(//g' -e 's/)//g' -e "s/'//g" -e 's/"//g'))) && \
	rm -f $(addsuffix /built, $(shell grep ' $*' Makefile | cut -d':' -f1)) && \
	repo-remove $(LOCAL)/$(REPO).db.tar.gz $(shell grep -R '^pkgname' $*/PKGBUILD | sed -e 's/pkgname=//' -e 's/(//g' -e 's/)//g' -e "s/'//g" -e 's/"//g') ; \
	mv $*/*$(PKGEXT) $(LOCAL) && \
	repo-add $(LOCAL)/$(REPO).db.tar.gz $(addsuffix *, $(addprefix $(LOCAL)/, $(shell grep -R '^pkgname' $*/PKGBUILD | sed -e 's/pkgname=//' -e 's/(//g' -e 's/)//g' -e "s/'//g" -e 's/"//g'))) && \
	if [ -f $(PWD)/$*/$$_gitname/HEAD ]; then \
		cd $(PWD)/$*/$$_gitname && \
		git log -1 | head -n1 > $(PWD)/$*/built ; \
	else \
		touch $(PWD)/$*/built ; \
	fi

rebuildrepo:
	cd $(LOCAL)
	rm -rf $(LOCAL)/$(REPO).db*
	repo-add $(LOCAL)/$(REPO).db.tar.gz $(LOCAL)/*$(PKGEXT)

$(DIRS):
	@_gitroot=$$(grep -R '^_gitroot' $(PWD)/$@/PKGBUILD | sed -e 's/_gitroot=//' -e "s/'//g" -e 's/"//g') && \
	_gitname=$$(grep -R '^_gitname' $(PWD)/$@/PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') && \
	if [ -z $$_gitroot ]; then \
		$(MAKE) $@/built ; \
	else \
		if [ -f $(PWD)/$@/$$_gitname/HEAD ]; then \
			echo "Updating $$_gitname" ; \
			cd $(PWD)/$@/$$_gitname && $(GITFETCH) && \
			if [ -f $(PWD)/$@/built ] && [ "$$(cat $(PWD)/$@/built)" != "$$(git log -1 | head -n1)" ]; then \
				rm -f $(PWD)/$@/built ; \
			fi ; \
			cd $(PWD) ; \
		else \
			echo "Cloning $$_gitroot to $@/$$_gitname" ; \
			$(GITCLONE) $$_gitroot $(PWD)/$@/$$_gitname ; \
		fi ; \
		$(MAKE) $@/built ; \
	fi ; \

PULL_TARGETS=$(addsuffix -pull, $(DIRS))

gitpull: $(PULL_TARGETS)

%-pull:
	@_gitroot=$$(grep -R '^_gitroot' $(PWD)/$*/PKGBUILD | sed -e 's/_gitroot=//' -e "s/'//g" -e 's/"//g') && \
	_gitname=$$(grep -R '^_gitname' $(PWD)/$*/PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') && \
	if [ -f $(PWD)/$*/$$_gitname/HEAD ]; then \
		echo "Updating $$_gitname" ; \
		cd $(PWD)/$*/$$_gitname && \
		$(GITFETCH) && \
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

PROTOS=$(shell ls | grep 'proto-git')

$(PROTOS): xorg-util-macros-git

libxdmcp-git: xproto-git

libxau-git: xproto-git

libxcb-git: xcb-proto-git libxdmcp-git libxau-git

libx11-git: libxcb-git xproto-git kbproto-git xextproto-git xtrans-git inputproto-git

xcb-util-git: libxcb-git xproto-git

xcb-util-image-git: libxcb-git xcb-util-git

xcb-util-keysyms-git: libxcb-git xcb-util-git

xcb-util-wm-git: libxcb-git xcb-util-git

libxext-git: libx11-git xextproto-git

libxrender-git: libx11-git renderproto-git

libxrandr-git: libxext-git libxrender-git randrproto-git

libxi-git: libxext-git inputproto-git

libxtst-git: recordproto-git inputproto-git libxext-git libxi-git

libxt: libsm-git libx11-git

libsm-git: libice-git xtrans-git xorg-util-macros-git

libxres-git: resourceproto-git damageproto-git compositeproto-git scrnsaverproto-git libxext-git

libdmx-git: dmxproto-git libxext-git

libxfixes-git: libx11-git fixesproto-git

libxdamage-git: libxfixes-git damageproto-git

libxcomposite-git: libxfixes-git compositeproto-git

libxxf86vm-git: xf86vidmodeproto-git libxext-git

libxxf86dga-git: libxext-git xf86dgaproto-git

libice: xproto-git xtrans-git

libpciaccess-git: xorg-util-macros-git

libvdpau-git: libx11-git

libdrm-git: libpciaccess-git

cairo-git: libxrender-git pixman-git xcb-util-git

libclc-git: llvm-git

mesa-git: glproto-git libdrm-git llvm-git libclc-git libxfixes-git libxdamage-git libxxf86vm-git libxvmc-git wayland-git

lib32-mesa-git: glproto-git lib32-libdrm-git lib32-llvm-git lib32-libvdpau-git lib32-wayland-git

lib32-llvm-git: llvm-git

glu-git: mesa-git

mesa-demos-git: mesa-git

libxv-git: libxext-git videoproto-git

libxvmc-git: libxv-git

libfontenc-git: xproto-git

libxcursor-git: libxfixes-git libxrender-git xorg-util-macros-git

libxfont-git: libfontenc-git xproto-git fontsproto-git xtrans-git

libxmu-git: libxext-git libxt-git

libxpm-git: libxt-git libxext-git

libxaw-git: libxmu-git libxpm-git

xorg-font-util-git: xorg-util-macros-git

xorg-setxkbmap-git: libxkbfile-git xorg-util-macros-git

xorg-server-git: bigreqsproto-git compositeproto-git dmxproto-git dri2proto-git fontsproto-git glproto-git inputproto-git randrproto-git recordproto-git renderproto-git resourceproto-git scrnsaverproto-git videoproto-git xcmiscproto-git xextproto-git xf86dgaproto-git xf86driproto-git xineramaproto-git libdmx-git libdrm-git libpciaccess-git libx11-git libxau-git libxaw-git libxdmcp-git libxext-git libxfixes-git libxfont-git libxi-git libxkbfile-git libxmu-git libxrender-git libxres-git libxtst-git libxv-git mesa-git pixman-git xkeyboard-config-git xorg-font-util-git xorg-setxkbmap-git xorg-util-macros-git xorg-xkbcomp-git xtrans-git wayland-git xcb-util-image-git xcb-util-wm-git

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

xf86-video-ati-git: xorg-server-git mesa-git glamor-git libdrm-git libpciaccess-git pixman-git xf86driproto-git glproto-git

radeontop-git: xf86-video-ati-git

xf86-video-intel-git: xorg-server-git mesa-git libxvmc-git libpciaccess-git libdrm-git dri2proto-git libxfixes-git libx11-git xf86driproto-git glproto-git resourceproto-git xcb-util-git

xf86-video-nouveau-git: libdrm-git mesa-git xorg-server-git

glamor-git: xorg-server-git mesa-git

weston-git: libxkbcommon-git wayland-git mesa-git cairo-git libxcursor-git pixman-git glu-git
