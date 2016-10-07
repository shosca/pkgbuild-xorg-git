REPO=xorg-git
PWD=$(shell pwd)
DIRS=$(shell ls -d */ | sed -e 's/\///' )
ARCHNSPAWN=arch-nspawn
MAKECONTAINER=/usr/bin/mkarchroot -C /usr/share/devtools/pacman-multilib.conf
PKGEXT=pkg.tar.xz
MACHINES=/var/lib/machines
BASEMACHINE=$(MACHINES)/root-$(REPO)
LOCKFILE=/tmp/$(REPO)-sync.lock
PACMAN=pacman -q
REPOADD=repo-add -n --nocolor -R

TARGETS=$(addsuffix /built, $(DIRS))
PULL_TARGETS=$(addsuffix -pull, $(DIRS))
SHA_TARGETS=$(addsuffix -sha, $(DIRS))
INFO_TARGETS=$(addsuffix -info, $(DIRS))
BUILD_TARGETS=$(addsuffix -build, $(DIRS))
CHECKVER_TARGETS=$(addsuffix -checkver, $(DIRS))

.PHONY: $(DIRS) container

all:
	@$(MAKE) build && \
	$(MAKE) clean && \
	$(MAKE) repopush push

clean:
	@sudo rm -rf */*.log */pkg */src */logpipe* $(BASEMACHINE)

resetall: clean
	@sudo rm -f */built ; \
	sed --follow-symlinks -i "s/^pkgrel=[^ ]*/pkgrel=0/" $(PWD)/**/PKGBUILD ; \

container:
	@if [[ ! -f $(BASEMACHINE)/.arch-chroot ]]; then \
		sudo mkdir -p $(BASEMACHINE); \
		sudo rm -rf $(BASEMACHINE); \
		sudo $(MAKECONTAINER) $(BASEMACHINE) base-devel ; \
		sudo cp $(PWD)/pacman.conf $(BASEMACHINE)/etc/pacman.conf ;\
		sudo cp $(PWD)/makepkg.conf $(BASEMACHINE)/etc/makepkg.conf ;\
		sudo cp $(PWD)/locale.conf $(BASEMACHINE)/etc/locale.conf ;\
		echo "MAKEFLAGS='-j$$(grep processor /proc/cpuinfo | wc -l)'" | sudo tee -a $(BASEMACHINE)/etc/makepkg.conf ;\
		sudo mkdir -p $(BASEMACHINE)/repo ;\
		sudo bsdtar -czf $(BASEMACHINE)/repo/$(REPO).db.tar.gz -T /dev/null ; \
		sudo ln -sf $(REPO).db.tar.gz $(BASEMACHINE)/repo/$(REPO).db ; \
		sudo $(ARCHNSPAWN) $(BASEMACHINE) /bin/bash -c "yes | $(PACMAN) -Syu ; yes | $(PACMAN) -S git gcc-multilib gcc-libs-multilib p7zip vim && chmod 777 /tmp" ; \
		echo "builduser ALL = NOPASSWD: /usr/bin/pacman" | sudo tee -a $(BASEMACHINE)/etc/sudoers.d/builduser ; \
		echo "builduser:x:$${SUDO_UID:-$$UID}:100:builduser:/:/usr/bin/bash" | sudo tee -a $(BASEMACHINE)/etc/passwd ; \
		sudo mkdir -p $(BASEMACHINE)/build; \
		sudo sed -i '/securetty/d' $(BASEMACHINE)/etc/pam.d/* ; \
		sudo $(ARCHNSPAWN) $(BASEMACHINE) bash -c "echo builduser:buildme | chpasswd" ; \
	fi ; \

build: $(DIRS)

check:
	@echo "==> REPO: $(REPO)" ; \
	echo "==> UID: $${SUDO_UID:-$$UID}" ; \
	for d in $(DIRS) ; do \
		if [[ ! -f $$d/built ]]; then \
			$(MAKE) --silent -C $(PWD) $$d-files; \
		fi \
	done

info: $(INFO_TARGETS)

%-info:
	@cd $(PWD)/$* ; \
	makepkg --printsrcinfo | grep depends | while read p; do \
		echo "$*: $$p" ; \
	done ; \

%-container: container
	@echo "==> Setting up container for [$*]" ; \
	sudo rsync -a --delete -q -W -x $(BASEMACHINE)/* $(MACHINES)/$* ; \

%-sync: %-container
	@echo "==> Syncing packages for [$*]" ; \
	if ls */*.$(PKGEXT) &> /dev/null ; then \
		sudo cp -f */*.$(PKGEXT) $(MACHINES)/$*/repo ; \
		sudo $(REPOADD) $(MACHINES)/$*/repo/$(REPO).db.tar.gz $(MACHINES)/$*/repo/*.$(PKGEXT) > /dev/null 2>&1 ; \
	fi ; \

%/built: %-sync
	@echo "==> Building [$*]" ; \
	rm -f *.log ; \
	mkdir -p $(PWD)/$*/tmp ; mv $(PWD)/$*/*$(PKGEXT) $(PWD)/$*/tmp ; \
	sudo mkdir -p $(MACHINES)/$*/build ; \
	sudo rsync -a --delete -q -W -x $(PWD)/$* $(MACHINES)/$*/build/ ; \
	_pkgrel=$$(grep '^pkgrel=' $(MACHINES)/$*/build/$*/PKGBUILD | cut -d'=' -f2 ) ;\
	_pkgrel=$$(($$_pkgrel+1)) ; \
	sed -i "s/^pkgrel=[^ ]*/pkgrel=$$_pkgrel/" $(MACHINES)/$*/build/$*/PKGBUILD ; \
	sudo systemd-nspawn -q -D $(MACHINES)/$* /bin/bash -c 'yes | $(PACMAN) -Syu && chown builduser -R /build && cd /build/$* && sudo -u builduser makepkg -L --noconfirm --holdver --nocolor -sf > makepkg.log'; \
	_pkgver=$$(bash -c "cd $(PWD)/$* ; source PKGBUILD ; if type -t pkgver | grep -q '^function$$' 2>/dev/null ; then srcdir=$$(pwd) pkgver ; fi") ; \
	if [ -z "$$_pkgver" ] ; then \
		_pkgver=$$(grep '^pkgver=' $(PWD)/$*/PKGBUILD | sed -e "s/'\|\"\|.*=//g") ; \
	fi ; \
	_pkgnames=$$(grep -Pzo "pkgname=\((?s)(.*?)\)" $(PWD)/$*/PKGBUILD | sed -e "s/\|'\|\"\|(\|)\|.*=//g") ; \
	if [ -z "$$_pkgnames" ] ; then \
		_pkgnames=$$(grep '^pkgname=' $(PWD)/$*/PKGBUILD | sed -e "s/'\|\"\|.*=//g") ; \
	fi ; \
	for pkgname in $$_pkgnames; do \
		if ! ls $(MACHINES)/$*/build/$*/$$pkgname-*$$_pkgver-$$_pkgrel-*$(PKGEXT) 1> /dev/null 2>&1; then \
			echo "==> Could not find $(MACHINES)/$*/build/$*/$$pkgname-*$$_pkgver-$$_pkgrel-*$(PKGEXT)" ; \
			rm -f $(PWD)/$*/*.$(PKGEXT) ; \
			mv $(PWD)/$*/tmp/*.$(PKGEXT) $(PWD)/$*/ && rm -rf $(PWD)/$*/tmp ; \
			exit 1; \
		else \
			cp $(MACHINES)/$*/build/$*/$$pkgname-*$$_pkgver-*$(PKGEXT) $(PWD)/$*/ ; \
		fi ; \
	done ; \
	cp $(MACHINES)/$*/build/$*/*.log $(PWD)/$*/ ; \
    cp $(MACHINES)/$*/build/$*/PKGBUILD $(PWD)/$*/PKGBUILD ; \
	rm -rf $(PWD)/$*/tmp ; \
	touch $(PWD)/$*/built

$(DIRS): container
	@if [ ! -f $(PWD)/$@/built ]; then \
		if ! $(MAKE) $@/built ; then \
			exit 1 ; \
		fi ; \
	fi ; \
	sudo rm -rf $(MACHINES)/$@ $(MACHINES)/$@.lock

%-deps:
	@echo "==> Marking dependencies for rebuild [$*]" ; \
	rm -f $(PWD)/$*/built ; \
	for dep in $$(grep ' $* ' $(PWD)/Makefile | cut -d':' -f1) ; do \
		$(MAKE) -s -C $(PWD) $$dep-deps ; \
	done ; \


srcpull: $(PULL_TARGETS)

%-vcs:
	@_gitroot=$$(grep '^_gitroot' $(PWD)/$*/PKGBUILD | sed -e "s/'\|\"\|.*=//g") && \
	_hgroot=$$(grep '^_hgroot' $(PWD)/$*/PKGBUILD | sed -e "s/'\|\"\|.*=//g") && \
	if [ ! -z "$$_gitroot" ] ; then \
		_gitname=$$(grep '^_gitname' $(PWD)/$*/PKGBUILD | sed -e "s/'\|\"\|.*=//g") && \
		if [ -f $(PWD)/$*/$$_gitname/HEAD ]; then \
			for f in $(PWD)/$*/*/HEAD; do \
				git --git-dir=$$(dirname $$f) remote update --prune ; \
			done ; \
		else \
			git clone --mirror $$_gitroot $(PWD)/$*/$$_gitname ; \
		fi ; \
	elif [ ! -z "$$_hgroot" ] ; then \
		_hgname=$$(grep '^_hgname' $(PWD)/$*/PKGBUILD | sed -e "s/'\|\"\|.*=//g") && \
		if [ -d $(PWD)/$*/$$_hgname/.hg ]; then \
			for f in $(PWD)/$*/*/.hg; do \
				hg --cwd=$$(dirname $$f) pull ; \
			done ; \
		else \
			 hg clone -U $$_hgroot $(PWD)/$*/$$_hgname ; \
		fi ; \
	fi ; \

%-pull: %-vcs
	@_pkgver=$$(bash -c "cd $(PWD)/$* ; source PKGBUILD ; if type -t pkgver | grep -q '^function$$' 2>/dev/null ; then pkgver ; fi") ; \
	if [ ! -z "$$_pkgver" ] ; then \
		echo "==> Updating pkgver [$*]" ; \
		sed -i "s/^pkgver=[^ ]*/pkgver=$$_pkgver/" $(PWD)/$*/PKGBUILD ; \
	else \
		_pkgver=$$(grep '^pkgver=' $(PWD)/$*/PKGBUILD | sed -e "s/'\|\"\|.*=//g") ; \
	fi ; \
	if [ ! -z "$$_pkgver" ] ; then \
		_pkgnames=$$(grep -Pzo "pkgname=\((?s)(.*?)\)" $(PWD)/$*/PKGBUILD | sed -e "s/\|'\|\"\|(\|)\|.*=//g") ; \
		if [ -z "$$_pkgnames" ] ; then \
			_pkgnames=$$(grep '^pkgname=' $(PWD)/$*/PKGBUILD | sed -e "s/'\|\"\|.*=//g") ; \
		fi ; \
		for pkgname in $$_pkgnames; do \
			if ! ls $(PWD)/$*/$$pkgname-*$$_pkgver-*$(PKGEXT) 1> /dev/null 2>&1; then \
				echo "==> Updating pkgrel [$*]" ; \
				sed -i "s/^pkgrel=[^ ]*/pkgrel=0/" $(PWD)/$*/PKGBUILD ; \
				$(MAKE) -s -C $(PWD) $*-deps ; \
				break ; \
			fi ; \
		done ; \
	fi ; \

checkvers: $(CHECKVER_TARGETS)

%-checkver:
	@_pkgver=$$(bash -c "cd $(PWD)/$* ; source PKGBUILD ; if type -t pkgver | grep -q '^function$$' 2>/dev/null ; then pkgver ; fi") ; \
	if [ ! -z "$$_pkgver" ] ; then \
		echo "==> Updating pkgver [$*]" ; \
		sed -i "s/^pkgver=[^ ]*/pkgver=$$_pkgver/" $(PWD)/$*/PKGBUILD ; \
	else \
		_pkgver=$$(grep '^pkgver=' $(PWD)/$*/PKGBUILD | sed -e "s/'\|\"\|.*=//g") ; \
	fi ; \
	echo "==> Package [$*]: $$_pkgver" ; \
	if [ ! -z "$$_pkgver" ] ; then \
		_pkgnames=$$(grep -Pzo "pkgname=\((?s)(.*?)\)" $(PWD)/$*/PKGBUILD | sed -e "s/\|'\|\"\|(\|)\|.*=//g") ; \
		if [ -z "$$_pkgnames" ] ; then \
			_pkgnames=$$(grep '^pkgname=' $(PWD)/$*/PKGBUILD | sed -e "s/'\|\"\|.*=//g") ; \
		fi ; \
		for pkgname in $$_pkgnames; do \
			if ! ls $(PWD)/$*/$$pkgname-*$$_pkgver-*$(PKGEXT) 1> /dev/null 2>&1; then \
				echo "==> Updating pkgrel [$*]" ; \
				sed -i "s/^pkgrel=[^ ]*/pkgrel=0/" $(PWD)/$*/PKGBUILD ; \
				$(MAKE) -s -C $(PWD) $*-deps ; \
				break ; \
			fi ; \
		done ; \
	fi ; \

%-files:
	@_pkgver=$$(grep '^pkgver=' $(PWD)/$*/PKGBUILD | sed -e "s/'\|\"\|.*=//g") ; \
	_pkgrel=$$(grep '^pkgrel=' $(PWD)/$*/PKGBUILD | sed -e "s/'\|\"\|.*=//g") ; \
	_fullver="$$_pkgver-$$_pkgrel" ; \
	_pkgnames=$$(grep -Pzo "pkgname=\((?s)(.*?)\)" $(PWD)/$*/PKGBUILD | sed -e "s/\|'\|\"\|(\|)\|.*=//g") ; \
	if [ -z "$$_pkgnames" ] ; then \
		_pkgnames=$$(grep '^pkgname=' $(PWD)/$*/PKGBUILD | sed -e "s/'\|\"\|.*=//g") ; \
	fi ; \
	for _pkgname in $$_pkgnames; do \
		echo "==> Rebuild $*: $$_pkgname-$$_fullver" ; \
	done ; \

updateshas: $(SHA_TARGETS)

%-sha:
	@cd $(PWD)/$* && updpkgsums

-include Makefile.mk

libomxil-bellagio: container

xorg-util-macros: container

bigreqsproto: xorg-util-macros container

compositeproto: xorg-util-macros container

damageproto: xorg-util-macros container

presentproto: xorg-util-macros container

dmxproto: xorg-util-macros container

dri2proto: xorg-util-macros container

dri3proto: xorg-util-macros container

fixesproto: xorg-util-macros xproto xextproto container

fontsproto: xorg-util-macros container

glproto: xorg-util-macros container

inputproto: xorg-util-macros container

kbproto: xorg-util-macros container

randrproto: xorg-util-macros container

recordproto: xorg-util-macros container

renderproto: xorg-util-macros container

resourceproto: xorg-util-macros container

scrnsaverproto: xorg-util-macros container

videoproto: xorg-util-macros container

xcb-proto: xorg-util-macros container

xcmiscproto: xorg-util-macros container

xextproto: xorg-util-macros container

xf86dgaproto: xorg-util-macros container

xf86driproto: xorg-util-macros container

xf86vidmodeproto: xorg-util-macros container

xineramaproto: xorg-util-macros container

xproto: xorg-util-macros container

pixman: xorg-util-macros container

wayland-protocols: container

wayland: xorg-util-macros wayland-protocols container

libpciaccess: xorg-util-macros container

libshmfence: xorg-util-macros container

libpthread-stubs: container

libdrm: libpciaccess xorg-util-macros container

libfontenc: xproto xorg-font-util container

libxdmcp: xproto container

libxau: xproto container

libxcb: xcb-proto libxdmcp libxau container

libx11: xproto kbproto xextproto xtrans inputproto libxcb container

xcb-util: xproto libxcb container

xcb-util-image: xcb-util container

xcb-util-keysyms: xcb-util container

xcb-util-wm: xcb-util container

xcb-util-renderutil: xcb-util container

llvm: container

libxext: xextproto libx11 container

libxrender: renderproto libx11 container

libxrandr: randrproto libxext libxrender container

libxi: inputproto libxext container

libxtst: recordproto inputproto libxi container

libice: xproto xtrans container

libsm: libice xtrans xorg-util-macros container

libxt: libx11 libsm container

libxmu: libxext libxt container

libxpm: libxt libxext container

libxaw: libxmu libxpm container

libxres: resourceproto damageproto compositeproto scrnsaverproto libxext container

libdmx: dmxproto libxext container

libxfixes: fixesproto libx11 container

libxdamage: damageproto libxfixes container

libxcomposite: compositeproto libxfixes container

libxxf86vm: xf86vidmodeproto libxext container

libxxf86dga: xf86dgaproto libxext container

libxv: videoproto libxext container

libxvmc: libxv container

libvdpau: libx11 libxext container

vdpauinfo: libvdpau container

libva: libdrm libxfixes container

libva-intel-driver: libva container

libva-vdpau-driver: libva libvdpau mesa container

libxcursor: libxfixes libxrender container

libxfont: xproto fontsproto libfontenc xtrans container

libxinerama: libxext xineramaproto container

libxkbfile: libx11 container

libxshmfence: xproto container

libevdev: container

libinput: libevdev container

freerdp: libxinerama libxcursor libxkbfile wayland container

cairo: libxrender pixman xcb-util mesa container

libclc: llvm container

libepoxy: mesa xorg-util-macros container

libxkbcommon: xkeyboard-config container

mesa: glproto libdrm llvm libclc libxfixes libvdpau libxdamage libxxf86vm libxvmc wayland libomxil-bellagio libxshmfence dri2proto dri3proto presentproto libpthread-stubs container

glu: mesa container

glew: libxmu glu container

freeglut: libxi libxrandr mesa glu libxxf86vm container

mesa-demos: mesa glew freeglut container

xorg-font-util: xorg-util-macros container

xorg-setxkbmap: libxkbfile xorg-util-macros container

xorg-server: bigreqsproto presentproto compositeproto dmxproto dri2proto dri3proto fontsproto glproto inputproto randrproto recordproto renderproto resourceproto scrnsaverproto videoproto xcmiscproto xextproto xf86dgaproto xf86driproto xineramaproto libdmx libdrm libpciaccess libx11 libxau libxaw libxdmcp libxext libxfixes libxfont libxi libxkbfile libxmu libxrender libxres libxtst libxv libepoxy mesa pixman xkeyboard-config xorg-font-util xorg-setxkbmap xorg-util-macros xorg-xkbcomp xtrans wayland xcb-util-image xcb-util-wm xcb-util-keysyms xcb-util-renderutil libxshmfence container

xorg-xauth: libxmu container

xorg-xkbcomp: libxkbfile container

xorg-xrdb: libxmu container

xorg-xrandr: libxrandr libx11 container

xorg-xprop: libx11 container

xorg-xev: libx11 libxrandr xproto container

xorg-xset: libxmu xorg-util-macros container

xorg-mkfontscale: libfontenc xproto container

xorg-xwininfo: libxcb libx11 container

xorg-xmessage: libxaw container

xorg-fonts-alias: container

xorg-fonts-encodings: xorg-mkfontscale xorg-util-macros xorg-font-util container

xf86-input-evdev: xorg-server libevdev libxi libxtst resourceproto scrnsaverproto container

xf86-input-libinput: xorg-server libinput libxi libxtst resourceproto scrnsaverproto container

xf86-input-synaptics: xorg-server libevdev libxi libxtst resourceproto scrnsaverproto container

xf86-input-joystick: xorg-server resourceproto scrnsaverproto container

xf86-input-keyboard: xorg-server resourceproto scrnsaverproto container

xf86-input-mouse: xorg-server resourceproto scrnsaverproto container

xf86-input-vmmouse: xorg-server resourceproto scrnsaverproto container

xf86-input-void: xorg-server resourceproto scrnsaverproto container

xf86-input-vesa: xorg-server resourceproto scrnsaverproto container

xf86-input-wacom: xorg-server libevdev libxi libxtst resourceproto scrnsaverproto container

xf86-video-ati: xorg-server mesa libdrm libpciaccess pixman xf86driproto glproto container

xf86-video-amdgpu: xorg-server mesa libdrm libpciaccess pixman xf86driproto glproto container

xtrans: container

xkeyboard-config: kbproto xcb-proto xproto libx11 libxau libxcb libxdmcp libxkbfile xorg-xkbcomp container

libxklavier: libxi xkeyboard-config container

xf86-video-intel: xorg-server mesa libxvmc libpciaccess libdrm dri2proto dri3proto libxfixes libx11 xf86driproto glproto resourceproto xcb-util container

xf86-video-nouveau: libdrm mesa xorg-server container

xf86-video-fbdev: xorg-server container

xf86-video-vesa: xorg-server container

weston: libinput libxkbcommon wayland mesa cairo libxcursor pixman glu wayland-protocols container

lib32-libpciaccess: libpciaccess container

lib32-pixman: pixman container

lib32-libxdmcp: libxdmcp container

lib32-libice: libice container

lib32-libxau: libxau container

lib32-libxcb: libxcb lib32-libxdmcp  lib32-libxau container

lib32-libx11: libx11 lib32-libxcb container

lib32-libxrender: libxrender lib32-libx11 container

lib32-libxext: libxext lib32-libx11 container

lib32-libxv: libxv lib32-libxext container

lib32-libxvmc: libxvmc lib32-libxv container

lib32-libvdpau: libvdpau lib32-libx11 container

lib32-libxxf86vm: libxxf86vm lib32-libxext container

lib32-libxfixes: libxfixes lib32-libx11 container

lib32-libxdamage: libxdamage lib32-libxfixes container

lib32-libsm: libsm lib32-libice container

lib32-libxt: libxt lib32-libsm lib32-libx11 container

lib32-wayland: wayland container

lib32-libdrm: libdrm lib32-libpciaccess container

lib32-mesa: glproto lib32-libxshmfence lib32-libdrm lib32-llvm lib32-libxvmc lib32-libvdpau lib32-libxxf86vm lib32-libxdamage lib32-libx11 lib32-libxt lib32-wayland mesa lib32-libxshmfence lib32-libpthread-stubs container

lib32-llvm: llvm container

lib32-libxshmfence: libxshmfence container

lib32-libpthread-stubs: libpthread-stubs container
