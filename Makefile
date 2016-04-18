REPO=xorg-git
PWD=$(shell pwd)
DIRS=$(shell ls -d */ | sed -e 's/\///' )
ARCHNSPAWN=arch-nspawn
MKARCHROOT=/usr/bin/mkarchroot -C /usr/share/devtools/pacman-multilib.conf
PKGEXT=pkg.tar.xz
GITCLONE=git clone --mirror
CHROOTPATH64=/var/chroot64/$(REPO)
LOCKFILE=/tmp/$(REPO)-sync.lock
PACMAN=pacman -q
REPOADD=repo-add -n --nocolor -R

TARGETS=$(addsuffix /built, $(DIRS))
PULL_TARGETS=$(addsuffix -pull, $(DIRS))
SHA_TARGETS=$(addsuffix -sha, $(DIRS))
INFO_TARGETS=$(addsuffix -info, $(DIRS))
BUILD_TARGETS=$(addsuffix -build, $(DIRS))

.PHONY: $(DIRS) chroot

all:
	@$(MAKE) gitpull
	$(MAKE) build

clean:
	@sudo rm -rf */*.log */pkg */src */logpipe* $(CHROOTPATH64)

resetall: clean
	@sudo rm -f */built ; \
	sed --follow-symlinks -i "s/^pkgrel=[^ ]*/pkgrel=0/" $(PWD)/**/PKGBUILD ; \

chroot:
	@if [[ ! -f $(CHROOTPATH64)/root/.arch-chroot ]]; then \
		sudo mkdir -p $(CHROOTPATH64); \
		sudo rm -rf $(CHROOTPATH64)/root; \
		sudo $(MKARCHROOT) $(CHROOTPATH64)/root base-devel ; \
		sudo cp $(PWD)/pacman.conf $(CHROOTPATH64)/root/etc/pacman.conf ;\
		sudo cp $(PWD)/makepkg.conf $(CHROOTPATH64)/root/etc/makepkg.conf ;\
		sudo cp $(PWD)/locale.conf $(CHROOTPATH64)/root/etc/locale.conf ;\
		echo "MAKEFLAGS='-j$$(grep processor /proc/cpuinfo | wc -l)'" | sudo tee -a $(CHROOTPATH64)/root/etc/makepkg.conf ;\
		sudo mkdir -p $(CHROOTPATH64)/root/repo ;\
		sudo bsdtar -czf $(CHROOTPATH64)/root/repo/$(REPO).db.tar.gz -T /dev/null ; \
		sudo ln -sf $(REPO).db.tar.gz $(CHROOTPATH64)/root/repo/$(REPO).db ; \
		sudo $(ARCHNSPAWN) $(CHROOTPATH64)/root /bin/bash -c 'yes | $(PACMAN) -Syu ; yes | $(PACMAN) -S gcc-multilib gcc-libs-multilib p7zip && chmod 777 /tmp' ; \
		echo 'builduser ALL = NOPASSWD: /usr/bin/pacman' | sudo tee -a $(CHROOTPATH64)/root/etc/sudoers.d/builduser ; \
		echo 'builduser:x:1000:100:builduser:/:/usr/bin/nologin\n' | sudo tee -a $(CHROOTPATH64)/root/etc/passwd ; \
		sudo mkdir -p $(CHROOTPATH64)/root/build; \
	fi ; \

build: $(DIRS)

check:
	@echo "==> REPO: $(REPO)" ; \
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

%-chroot: chroot
	@echo "==> Setting up chroot for [$*]" ; \
	sudo rsync -a --delete -q -W -x $(CHROOTPATH64)/root/* $(CHROOTPATH64)/$* ; \

%-sync: %-chroot
	@echo "==> Syncing packages for [$*]" ; \
	if ls */*.$(PKGEXT) &> /dev/null ; then \
		sudo cp -f */*.$(PKGEXT) $(CHROOTPATH64)/$*/repo ; \
		sudo $(REPOADD) $(CHROOTPATH64)/$*/repo/$(REPO).db.tar.gz $(CHROOTPATH64)/$*/repo/*.$(PKGEXT) > /dev/null 2>&1 ; \
	fi ; \

%/built: %-sync
	@echo "==> Building [$*]" ; \
	rm -f *.log ; \
	mkdir -p $(PWD)/$*/tmp ; mv $(PWD)/$*/*$(PKGEXT) $(PWD)/$*/tmp ; \
	sudo mkdir -p $(CHROOTPATH64)/$*/build ; \
	sudo rsync -a --delete -q -W -x $(PWD)/$* $(CHROOTPATH64)/$*/build/ ; \
	_pkgrel=$$(grep '^pkgrel=' $(CHROOTPATH64)/$*/build/$*/PKGBUILD | cut -d'=' -f2 ) ;\
	_pkgrel=$$(($$_pkgrel+1)) ; \
	sed -i "s/^pkgrel=[^ ]*/pkgrel=$$_pkgrel/" $(CHROOTPATH64)/$*/build/$*/PKGBUILD ; \
	sudo systemd-nspawn -q -D $(CHROOTPATH64)/$* /bin/bash -c 'yes | $(PACMAN) -Syu && chown builduser -R /build && cd /build/$* && sudo -u builduser makepkg -L --noconfirm --holdver --nocolor -sf > makepkg.log'; \
	_pkgver=$$(bash -c "cd $(PWD)/$* ; source PKGBUILD ; if type -t pkgver | grep -q '^function$$' 2>/dev/null ; then srcdir=$$(pwd) pkgver ; fi") ; \
	if [ -z "$$_pkgver" ] ; then \
		_pkgver=$$(grep '^pkgver=' $(PWD)/$*/PKGBUILD | sed -e "s/'\|\"\|.*=//g") ; \
	fi ; \
	_pkgnames=$$(grep -Pzo "pkgname=\((?s)(.*?)\)" $(PWD)/$*/PKGBUILD | sed -e "s/\|'\|\"\|(\|)\|.*=//g") ; \
	if [ -z "$$_pkgnames" ] ; then \
		_pkgnames=$$(grep '^pkgname=' $(PWD)/$*/PKGBUILD | sed -e "s/'\|\"\|.*=//g") ; \
	fi ; \
	for pkgname in $$_pkgnames; do \
		if ! ls $(CHROOTPATH64)/$*/build/$*/$$pkgname-*$$_pkgver-$$_pkgrel-*$(PKGEXT) 1> /dev/null 2>&1; then \
			rm -f $(PWD)/$*/*.$(PKGEXT) ; \
			mv $(PWD)/$*/tmp/*.$(PKGEXT) $(PWD)/$*/ && rm -rf $(PWD)/$*/tmp ; \
			exit 1; \
		else \
			cp $(CHROOTPATH64)/$*/build/$*/$$pkgname-*$$_pkgver-*$(PKGEXT) $(PWD)/$*/ ; \
		fi ; \
	done ; \
	cp $(CHROOTPATH64)/$*/build/$*/*.log $(PWD)/$*/ ; \
    cp $(CHROOTPATH64)/$*/build/$*/PKGBUILD $(PWD)/$*/PKGBUILD ; \
	rm -rf $(PWD)/$*/tmp ; \
	touch $(PWD)/$*/built

$(DIRS): chroot
	@if [ ! -f $(PWD)/$@/built ]; then \
		if ! $(MAKE) $@/built ; then \
			exit 1 ; \
		fi ; \
	fi ; \
	sudo rm -rf $(CHROOTPATH64)/$@ $(CHROOTPATH64)/$@.lock

%-deps:
	@echo "==> Marking dependencies for rebuild [$*]" ; \
	rm -f $(PWD)/$*/built ; \
	for dep in $$(grep ' $* ' $(PWD)/Makefile | cut -d':' -f1) ; do \
		$(MAKE) -s -C $(PWD) $$dep-deps ; \
	done ; \


gitpull: $(PULL_TARGETS)

%-pull:
	@_gitroot=$$(grep '^_gitroot' $(PWD)/$*/PKGBUILD | sed -e "s/'\|\"\|.*=//g") && \
	_gitname=$$(grep '^_gitname' $(PWD)/$*/PKGBUILD | sed -e "s/'\|\"\|.*=//g") && \
	if [ ! -z "$$_gitroot" ] ; then \
		if [ -f $(PWD)/$*/$$_gitname/HEAD ]; then \
			for f in $(PWD)/$*/*/HEAD; do \
				git --git-dir=$$(dirname $$f) remote update --prune ; \
			done ; \
		else \
			$(GITCLONE) $$_gitroot $(PWD)/$*/$$_gitname ; \
		fi ; \
	fi ; \
	_pkgver=$$(bash -c "cd $(PWD)/$* ; source PKGBUILD ; if type -t pkgver | grep -q '^function$$' 2>/dev/null ; then pkgver ; fi") ; \
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

libomxil-bellagio: chroot

xorg-util-macros: chroot

bigreqsproto: xorg-util-macros chroot

compositeproto: xorg-util-macros chroot

damageproto: xorg-util-macros chroot

presentproto: xorg-util-macros chroot

dmxproto: xorg-util-macros chroot

dri2proto: xorg-util-macros chroot

dri3proto: xorg-util-macros chroot

fixesproto: xorg-util-macros xproto xextproto chroot

fontsproto: xorg-util-macros chroot

glproto: xorg-util-macros chroot

inputproto: xorg-util-macros chroot

kbproto: xorg-util-macros chroot

randrproto: xorg-util-macros chroot

recordproto: xorg-util-macros chroot

renderproto: xorg-util-macros chroot

resourceproto: xorg-util-macros chroot

scrnsaverproto: xorg-util-macros chroot

videoproto: xorg-util-macros chroot

xcb-proto: xorg-util-macros chroot

xcmiscproto: xorg-util-macros chroot

xextproto: xorg-util-macros chroot

xf86dgaproto: xorg-util-macros chroot

xf86driproto: xorg-util-macros chroot

xf86vidmodeproto: xorg-util-macros chroot

xineramaproto: xorg-util-macros chroot

xproto: xorg-util-macros chroot

pixman: xorg-util-macros chroot

wayland-protocols: chroot

wayland: xorg-util-macros wayland-protocols chroot

libpciaccess: xorg-util-macros chroot

libshmfence: xorg-util-macros chroot

libdrm: libpciaccess xorg-util-macros chroot

libfontenc: xproto xorg-font-util chroot

libxdmcp: xproto chroot

libxau: xproto chroot

libxcb: xcb-proto libxdmcp libxau chroot

libx11: xproto kbproto xextproto xtrans inputproto libxcb chroot

xcb-util: xproto libxcb chroot

xcb-util-image: xcb-util chroot

xcb-util-keysyms: xcb-util chroot

xcb-util-wm: xcb-util chroot

xcb-util-renderutil: xcb-util chroot

llvm: chroot

libxext: xextproto libx11 chroot

libxrender: renderproto libx11 chroot

libxrandr: randrproto libxext libxrender chroot

libxi: inputproto libxext chroot

libxtst: recordproto inputproto libxi chroot

libice: xproto xtrans chroot

libsm: libice xtrans xorg-util-macros chroot

libxt: libx11 libsm chroot

libxmu: libxext libxt chroot

libxpm: libxt libxext chroot

libxaw: libxmu libxpm chroot

libxres: resourceproto damageproto compositeproto scrnsaverproto libxext chroot

libdmx: dmxproto libxext chroot

libxfixes: fixesproto libx11 chroot

libxdamage: damageproto libxfixes chroot

libxcomposite: compositeproto libxfixes chroot

libxxf86vm: xf86vidmodeproto libxext chroot

libxxf86dga: xf86dgaproto libxext chroot

libxv: videoproto libxext chroot

libxvmc: libxv chroot

libvdpau: libx11 libxext chroot

vdpauinfo: libvdpau chroot

libva: libdrm libxfixes chroot

libva-intel-driver: libva chroot

libva-vdpau-driver: libva libvdpau mesa chroot

libxcursor: libxfixes libxrender chroot

libxfont: xproto fontsproto libfontenc xtrans chroot

libxinerama: libxext xineramaproto chroot

libxkbfile: libx11 chroot

libxshmfence: xproto chroot

libevdev: chroot

libinput: libevdev chroot

freerdp: libxinerama libxcursor libxkbfile wayland chroot

cairo: libxrender pixman xcb-util mesa chroot

libclc: llvm chroot

libepoxy: mesa xorg-util-macros chroot

libxkbcommon: xkeyboard-config chroot

mesa: glproto libdrm llvm libclc libxfixes libvdpau libxdamage libxxf86vm libxvmc wayland libomxil-bellagio libxshmfence dri2proto dri3proto presentproto chroot

glu: mesa chroot

glew: libxmu glu chroot

freeglut: libxi libxrandr mesa glu libxxf86vm chroot

mesa-demos: mesa glew freeglut chroot

xorg-font-util: xorg-util-macros chroot

xorg-setxkbmap: libxkbfile xorg-util-macros chroot

xorg-server: bigreqsproto presentproto compositeproto dmxproto dri2proto dri3proto fontsproto glproto inputproto randrproto recordproto renderproto resourceproto scrnsaverproto videoproto xcmiscproto xextproto xf86dgaproto xf86driproto xineramaproto libdmx libdrm libpciaccess libx11 libxau libxaw libxdmcp libxext libxfixes libxfont libxi libxkbfile libxmu libxrender libxres libxtst libxv libepoxy mesa pixman xkeyboard-config xorg-font-util xorg-setxkbmap xorg-util-macros xorg-xkbcomp xtrans wayland xcb-util-image xcb-util-wm xcb-util-keysyms xcb-util-renderutil libxshmfence chroot

xorg-xauth: libxmu chroot

xorg-xhost: libxmu chroot

xorg-xkbcomp: libxkbfile chroot

xorg-xrdb: libxmu chroot

xorg-xrandr: libxrandr libx11 chroot

xorg-xprop: libx11 chroot

xorg-xev: libx11 libxrandr xproto chroot

xorg-xset: libxmu xorg-util-macros chroot

xorg-mkfontscale: libfontenc xproto chroot

xorg-xwininfo: libxcb libx11 chroot

xorg-xmessage: libxaw chroot

xorg-fonts-alias: chroot

xorg-fonts-encodings: xorg-mkfontscale xorg-util-macros xorg-font-util chroot

xf86-input-evdev: xorg-server libevdev libxi libxtst resourceproto scrnsaverproto chroot

xf86-input-libinput: xorg-server libinput libxi libxtst resourceproto scrnsaverproto chroot

xf86-input-synaptics: xorg-server libevdev libxi libxtst resourceproto scrnsaverproto chroot

xf86-input-joystick: xorg-server resourceproto scrnsaverproto chroot

xf86-input-keyboard: xorg-server resourceproto scrnsaverproto chroot

xf86-input-mouse: xorg-server resourceproto scrnsaverproto chroot

xf86-input-vmmouse: xorg-server resourceproto scrnsaverproto chroot

xf86-input-void: xorg-server resourceproto scrnsaverproto chroot

xf86-input-vesa: xorg-server resourceproto scrnsaverproto chroot

xf86-input-wacom: xorg-server libevdev libxi libxtst resourceproto scrnsaverproto chroot

xf86-video-ati: xorg-server mesa libdrm libpciaccess pixman xf86driproto glproto chroot

xf86-video-amdgpu: xorg-server mesa libdrm libpciaccess pixman xf86driproto glproto chroot

radeontop: chroot

xtrans: chroot

xkeyboard-config: kbproto xcb-proto xproto libx11 libxau libxcb libxdmcp libxkbfile xorg-xkbcomp chroot

libxklavier: libxi xkeyboard-config chroot

xf86-video-intel: xorg-server mesa libxvmc libpciaccess libdrm dri2proto dri3proto libxfixes libx11 xf86driproto glproto resourceproto xcb-util chroot

xf86-video-nouveau: libdrm mesa xorg-server chroot

xf86-video-fbdev: xorg-server chroot

xf86-video-vesa: xorg-server chroot

weston: libinput libxkbcommon wayland mesa cairo libxcursor pixman glu wayland-protocols chroot

lib32-libpciaccess:chroot

lib32-pixman: pixman chroot

lib32-libxdmcp: libxdmcp chroot

lib32-libice: libice chroot

lib32-libxau: libxau chroot

lib32-libxcb: libxcb lib32-libxdmcp  lib32-libxau chroot

lib32-libx11: libx11 lib32-libxcb chroot

lib32-libxrender: libxrender lib32-libx11 chroot

lib32-libxext: libxext lib32-libx11 chroot

lib32-libxv: libxv lib32-libxext chroot

lib32-libxvmc: libxvmc lib32-libxv chroot

lib32-libvdpau: libvdpau lib32-libx11 chroot

lib32-libxxf86vm: libxxf86vm lib32-libxext chroot

lib32-libxfixes: libxfixes lib32-libx11 chroot

lib32-libxdamage: libxdamage lib32-libxfixes chroot

lib32-libsm: libsm lib32-libice chroot

lib32-libxt: libxt lib32-libsm lib32-libx11 chroot

lib32-wayland: wayland chroot

lib32-libdrm: libdrm lib32-libpciaccess chroot

lib32-mesa: glproto lib32-libxshmfence lib32-libdrm lib32-llvm lib32-libxvmc lib32-libvdpau lib32-libxxf86vm lib32-libxdamage lib32-libx11 lib32-libxt lib32-wayland mesa lib32-libxshmfence chroot

lib32-llvm: llvm chroot

lib32-libxshmfence: libxshmfence chroot

