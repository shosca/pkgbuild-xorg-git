REPO=xorg-git
PWD=$(shell pwd)
DIRS=$(shell ls -d */ | sed -e 's/\///' )
ARCHNSPAWN=arch-nspawn
MKARCHROOT=/usr/bin/mkarchroot -C /usr/share/devtools/pacman-multilib.conf
PKGEXT=pkg.tar.xz
GITFETCH=git remote update --prune
GITCLONE=git clone --mirror
CHROOTPATH64=/var/chroot64/$(REPO)
MAKECHROOTPKG=OPTIND=--holdver /usr/bin/makechrootpkg -c -u -r $(CHROOTPATH64)
LOCKFILE=$(CHROOTPATH64)/sync.lock

TARGETS=$(addsuffix /built, $(DIRS))
PULL_TARGETS=$(addsuffix -pull, $(DIRS))
VER_TARGETS=$(addsuffix -ver, $(DIRS))
SHA_TARGETS=$(addsuffix -sha, $(DIRS))

.PHONY: $(DIRS) checkchroot

all:
	$(MAKE) gitpull
	$(MAKE) build

clean:
	sudo rm -rf */*.log */pkg */src */logpipe* $(CHROOTPATH64)

reset: clean
	sudo rm -f */built ; \
	sed --follow-symlinks -i "s/^pkgrel=[^ ]*/pkgrel=0/" $(PWD)/**/PKGBUILD ; \

checkchroot: emptyrepo recreaterepo syncrepos

buildchroot:
	@if [ ! -d $(CHROOTPATH64) ]; then \
		echo "Creating working chroot at $(CHROOTPATH64)/root" ; \
		sudo mkdir -p $(CHROOTPATH64) ;\
		[[ ! -f $(CHROOTPATH64)/root/.arch-chroot ]] && sudo $(MKARCHROOT) $(CHROOTPATH64)/root base-devel ; \
		$(MAKE) installdeps ; \
	fi ; \

configchroot: buildchroot emptyrepo
	@sudo cp $(PWD)/pacman.conf $(CHROOTPATH64)/root/etc/pacman.conf ;\
	sudo cp $(PWD)/makepkg.conf $(CHROOTPATH64)/root/etc/makepkg.conf ;\
	sudo cp $(PWD)/locale.conf $(CHROOTPATH64)/root/etc/locale.conf ;\

emptyrepo: buildchroot
	@sudo mkdir -p $(CHROOTPATH64)/root/repo/ ; \
	sudo bsdtar -czf $(CHROOTPATH64)/root/repo/$(REPO).db.tar.gz -T /dev/null ; \
	sudo ln -sf $(REPO).db.tar.gz $(CHROOTPATH64)/root/repo/$(REPO).db ; \

installdeps: buildchroot syncrepos
	@sudo $(ARCHNSPAWN) $(CHROOTPATH64)/root /bin/bash -c 'pacman -Sy ; yes | pacman -S gcc-multilib gcc-libs-multilib p7zip' ; \

recreaterepo: buildchroot emptyrepo
	@echo "Recreating working repo $(REPO)" ; \
	if [[ -f $(LOCKFILE) ]]; then \
		while [[ -f $(LOCKFILE) ]]; do sleep 3; done \
	fi ; \
	sudo touch $(LOCKFILE) ; \
	sudo mkdir -p $(CHROOTPATH64)/root/repo ;\
	sudo cp $(PWD)/pacman.conf $(CHROOTPATH64)/root/etc/pacman.conf ;\
	if ls */*.$(PKGEXT) &> /dev/null ; then \
		sudo cp -f */*.$(PKGEXT) $(CHROOTPATH64)/root/repo ; \
		sudo cp -f */*.$(PKGEXT) /var/cache/pacman/pkg ; \
		sudo repo-add $(CHROOTPATH64)/root/repo/$(REPO).db.tar.gz $(CHROOTPATH64)/root/repo/*.$(PKGEXT) ; \
	fi ; \
	sudo rm $(LOCKFILE) ; \

syncrepos: buildchroot recreaterepo
	@if [[ -f $(LOCKFILE) ]]; then \
		while [[ -f $(LOCKFILE) ]]; do sleep 3; done \
	else \
		sudo touch $(LOCKFILE) ; \
		sudo $(ARCHNSPAWN) $(CHROOTPATH64)/root pacman -Syu --noconfirm ; \
		sudo rm $(LOCKFILE) ; \
	fi ; \

resetchroot:
	sudo rm -rf $(CHROOTPATH64) && $(MAKE) checkchroot


build: $(DIRS)

check:
	@echo "REPO    : $(REPO)" ; \
	echo "DIRS    : $(DIRS)" ; \
	echo "PKGEXT  : $(PKGEXT)" ; \
	echo "GITFETCH: $(GITFETCH)" ; \
	echo "GITCLONE: $(GITCLONE)" ; \
	for d in $(DIRS) ; do \
		if [[ ! -f $$d/built ]]; then \
			_newpkgver=$$(bash -c "source $$d/PKGBUILD ; srcdir="$$(pwd)/$$d" pkgver ;") ; \
			echo "$$d: $$_newpkgver" ; \
		fi \
	done

%/built:
	@_gitname=$$(grep -R '^_gitname' $(PWD)/$*/PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') && \
	cd $* ; \
	rm -f *.log ; \
	mkdir -p $(PWD)/$*/tmp ; mv $(PWD)/$*/*$(PKGEXT) $(PWD)/$*/tmp ; \
	sudo $(MAKECHROOTPKG) -l $* ; \
	if ! ls *.$(PKGEXT) &> /dev/null ; then \
		mv $(PWD)/$*/tmp/*.$(PKGEXT) $(PWD)/$*/ && rm -rf $(PWD)/$*/tmp ; \
		exit 1 ; \
	fi ; \
	rm -rf $(PWD)/$*/tmp ; \
	if [ -f $(PWD)/$*/$$_gitname/HEAD ]; then \
		cd $(PWD)/$*/$$_gitname ; git log -1 | head -n1 > $(PWD)/$*/built ; \
	else \
		touch $(PWD)/$*/built ; \
	fi ; \

$(DIRS): checkchroot
	@if [ ! -f $(PWD)/$@/built ]; then \
		_pkgrel=$$(grep -R '^pkgrel' $(PWD)/$@/PKGBUILD | sed -e 's/pkgrel=//' -e "s/'//g" -e 's/"//g') && \
		sed --follow-symlinks -i "s/^pkgrel=[^ ]*/pkgrel=$$(($$_pkgrel+1))/" $(PWD)/$@/PKGBUILD ; \
		if ! $(MAKE) $@/built ; then \
			sed --follow-symlinks -i "s/^pkgrel=[^ ]*/pkgrel=$$_pkgrel/" $(PWD)/$@/PKGBUILD ; \
			exit 1 ; \
		fi ; \
	fi ; \
	sudo rm -rf $(CHROOTPATH64)/$@

gitpull: $(PULL_TARGETS)

%-pull:
	@_gitroot=$$(grep -R '^_gitroot' $(PWD)/$*/PKGBUILD | sed -e 's/_gitroot=//' -e "s/'//g" -e 's/"//g') && \
	_gitname=$$(grep -R '^_gitname' $(PWD)/$*/PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') && \
	if [ ! -z "$$_gitroot" ] ; then \
		if [ -f $(PWD)/$*/$$_gitname/HEAD ]; then \
			for f in $(PWD)/$*/*/HEAD; do \
				cd $$(dirname $$f) && $(GITFETCH) ; \
			done ; \
			cd $(PWD)/$*/$$_gitname && \
			if [ -f $(PWD)/$*/built ] && [ "$$(cat $(PWD)/$*/built)" != "$$(git log -1 | head -n1)" ]; then \
				$(MAKE) -s -C $(PWD) $*-ver ; \
				$(MAKE) -s -C $(PWD) $*-rel ; \
				rm -f $(PWD)/$*/built ; \
				for dep in $$(grep ' $* ' $(PWD)/Makefile | cut -d':' -f1) ; do \
					rm -f $(PWD)/$$dep/built ; \
				done ; \
			fi ; \
		else \
			$(GITCLONE) $$_gitroot $(PWD)/$*/$$_gitname ; \
			rm -f $(PWD)/$*/built ; \
			for dep in $$(grep ' $* ' $(PWD)/Makefile | cut -d':' -f1) ; do \
				rm -f $(PWD)/$$dep/built ; \
			done ; \
		fi ; \
	fi ; \
	cd $(PWD)

vers: $(VER_TARGETS)

%-ver:
	@cd $(PWD)/$* ; \
	_newpkgver=$$(bash -c "source PKGBUILD ; srcdir=$$(pwd) pkgver ;") ; \
	sed --follow-symlinks -i "s/^pkgver=[^ ]*/pkgver=$$_newpkgver/" PKGBUILD ; \
	echo "$*: $$_newpkgver"

%-rel:
	@sed --follow-symlinks -i "s/^pkgrel=[^ ]*/pkgrel=0/" $(PWD)/$*/PKGBUILD ; \

updateshas: $(SHA_TARGETS)

%-sha:
	@cd $(PWD)/$* && updpkgsums

-include Makefile.mk

libomxil-bellagio: syncrepos

xorg-util-macros: syncrepos

bigreqsproto: xorg-util-macros syncrepos

compositeproto: xorg-util-macros syncrepos

damageproto: xorg-util-macros syncrepos

presentproto: xorg-util-macros syncrepos

dmxproto: xorg-util-macros syncrepos

dri2proto: xorg-util-macros syncrepos

dri3proto: xorg-util-macros syncrepos

fixesproto: xorg-util-macros xproto xextproto syncrepos

fontsproto: xorg-util-macros syncrepos

glproto: xorg-util-macros syncrepos

inputproto: xorg-util-macros syncrepos

kbproto: xorg-util-macros syncrepos

randrproto: xorg-util-macros syncrepos

recordproto: xorg-util-macros syncrepos

renderproto: xorg-util-macros syncrepos

resourceproto: xorg-util-macros syncrepos

scrnsaverproto: xorg-util-macros syncrepos

videoproto: xorg-util-macros syncrepos

xcb-proto: xorg-util-macros syncrepos

xcmiscproto: xorg-util-macros syncrepos

xextproto: xorg-util-macros syncrepos

xf86dgaproto: xorg-util-macros syncrepos

xf86driproto: xorg-util-macros syncrepos

xf86vidmodeproto: xorg-util-macros syncrepos

xineramaproto: xorg-util-macros syncrepos

xproto: xorg-util-macros syncrepos

pixman: xorg-util-macros syncrepos

wayland: xorg-util-macros wayland-protocols syncrepos

libpciaccess: xorg-util-macros syncrepos

libshmfence: xorg-util-macros syncrepos

libdrm: libpciaccess xorg-util-macros syncrepos

libfontenc: xproto xorg-font-util syncrepos

libxdmcp: xproto syncrepos

libxau: xproto syncrepos

libxcb: xcb-proto libxdmcp libxau syncrepos

libx11: xproto kbproto xextproto xtrans inputproto libxcb syncrepos

xcb-util: xproto libxcb syncrepos

xcb-util-image: xcb-util syncrepos

xcb-util-keysyms: xcb-util syncrepos

xcb-util-wm: xcb-util syncrepos

xcb-util-renderutil: xcb-util syncrepos

libxext: xextproto libx11 syncrepos

libxrender: renderproto libx11 syncrepos

libxrandr: randrproto libxext libxrender syncrepos

libxi: inputproto libxext syncrepos

libxtst: recordproto inputproto libxi syncrepos

libice: xproto xtrans syncrepos

libsm: libice xtrans xorg-util-macros syncrepos

libxt: libx11 libsm syncrepos

libxmu: libxext libxt syncrepos

libxpm: libxt libxext syncrepos

libxaw: libxmu libxpm syncrepos

libxres: resourceproto damageproto compositeproto scrnsaverproto libxext syncrepos

libdmx: dmxproto libxext syncrepos

libxfixes: fixesproto libx11 syncrepos

libxdamage: damageproto libxfixes syncrepos

libxcomposite: compositeproto libxfixes syncrepos

libxxf86vm: xf86vidmodeproto libxext syncrepos

libxxf86dga: xf86dgaproto libxext syncrepos

libxv: videoproto libxext syncrepos

libxvmc: libxv syncrepos

libvdpau: libx11 libxext syncrepos

vdpauinfo: libvdpau syncrepos

libva: libdrm libxfixes syncrepos

libva-intel-driver: libva syncrepos

libva-vdpau-driver: libva libvdpau mesa syncrepos

libxcursor: libxfixes libxrender syncrepos

libxfont: xproto fontsproto libfontenc xtrans syncrepos

libxkbfile: libx11 syncrepos

freerdp: libxinerama libxcursor libxkbfile wayland syncrepos

cairo: libxrender pixman xcb-util mesa syncrepos

libclc: llvm syncrepos

libepoxy: mesa xorg-util-macros syncrepos

libxkbcommon: xkeyboard-config syncrepos

mesa: glproto libdrm llvm libclc libxfixes libvdpau libxdamage libxxf86vm libxvmc wayland libomxil-bellagio libxshmfence dri2proto dri3proto presentproto syncrepos

glu: mesa syncrepos

glew: libxmu glu syncrepos

freeglut: libxi libxrandr mesa glu libxxf86vm syncrepos

mesa-demos: mesa glew freeglut syncrepos

xorg-font-util: xorg-util-macros syncrepos

xorg-setxkbmap: libxkbfile xorg-util-macros syncrepos

xorg-server: bigreqsproto presentproto compositeproto dmxproto dri2proto dri3proto fontsproto glproto inputproto randrproto recordproto renderproto resourceproto scrnsaverproto videoproto xcmiscproto xextproto xf86dgaproto xf86driproto xineramaproto libdmx libdrm libpciaccess libx11 libxau libxaw libxdmcp libxext libxfixes libxfont libxi libxkbfile libxmu libxrender libxres libxtst libxv libepoxy mesa pixman xkeyboard-config xorg-font-util xorg-setxkbmap xorg-util-macros xorg-xkbcomp xtrans wayland xcb-util-image xcb-util-wm xcb-util-keysyms xcb-util-renderutil libxshmfence syncrepos

xorg-xauth: libxmu syncrepos

xorg-xhost: libxmu syncrepos

xorg-xrdb: libxmu syncrepos

xorg-xrandr: libxrandr libx11 syncrepos

xorg-xprop: libx11 syncrepos

xorg-xev: libx11 libxrandr xproto syncrepos

xorg-xset: libxmu xorg-util-macros syncrepos

xorg-mkfontscale: libfontenc xproto syncrepos

xorg-xwininfo: libxcb libx11 syncrepos

xorg-xmessage: libxaw syncrepos

xorg-fonts-encodings: xorg-mkfontscale xorg-util-macros xorg-font-util syncrepos

xf86-input-evdev: xorg-server libevdev libxi libxtst resourceproto scrnsaverproto syncrepos

xf86-input-libinput: xorg-server libinput libxi libxtst resourceproto scrnsaverproto syncrepos

xf86-input-synaptics: xorg-server libevdev libxi libxtst resourceproto scrnsaverproto syncrepos

xf86-input-joystick: xorg-server resourceproto scrnsaverproto syncrepos

xf86-input-keyboard: xorg-server resourceproto scrnsaverproto syncrepos

xf86-input-mouse: xorg-server resourceproto scrnsaverproto syncrepos

xf86-input-vmmouse: xorg-server resourceproto scrnsaverproto syncrepos

xf86-input-void: xorg-server resourceproto scrnsaverproto syncrepos

xf86-input-vesa: xorg-server resourceproto scrnsaverproto syncrepos

xf86-input-wacom: xorg-server libevdev libxi libxtst resourceproto scrnsaverproto syncrepos

xf86-video-ati: xorg-server mesa libdrm libpciaccess pixman xf86driproto glproto syncrepos

xf86-video-amdgpu: xorg-server mesa libdrm libpciaccess pixman xf86driproto glproto syncrepos

radeontop: syncrepos

xkeyboard-config: kbproto xcb-proto xproto libx11 libxau libxcb libxdmcp libxkbfile xorg-xkbcomp syncrepos

libxklavier: libxi xkeyboard-config syncrepos

xf86-video-intel: xorg-server mesa libxvmc libpciaccess libdrm dri2proto dri3proto libxfixes libx11 xf86driproto glproto resourceproto xcb-util syncrepos

xf86-video-nouveau: libdrm mesa xorg-server syncrepos

xf86-video-fbdev: xorg-server syncrepos

weston: libinput libxkbcommon wayland mesa cairo libxcursor pixman glu wayland-protocols syncrepos

lib32-libpciaccess:syncrepos

lib32-pixman: pixman syncrepos

lib32-libxdmcp: libxdmcp syncrepos

lib32-libice: libice syncrepos

lib32-libxau: libxau syncrepos

lib32-libxcb: libxcb lib32-libxdmcp  lib32-libxau syncrepos

lib32-libx11: libx11 lib32-libxcb syncrepos

lib32-libxrender: libxrender lib32-libx11 syncrepos

lib32-libxext: libxext lib32-libx11 syncrepos

lib32-libxv: libxv lib32-libxext syncrepos

lib32-libxvmc: libxvmc lib32-libxv syncrepos

lib32-libvdpau: libvdpau lib32-libx11 syncrepos

lib32-libxxf86vm: libxxf86vm lib32-libxext syncrepos

lib32-libxfixes: libxfixes lib32-libx11 syncrepos

lib32-libxdamage: libxdamage lib32-libxfixes syncrepos

lib32-libsm: libsm lib32-libice syncrepos

lib32-libxt: libxt lib32-libsm lib32-libx11 syncrepos

lib32-wayland: wayland syncrepos

lib32-libdrm: libdrm lib32-libpciaccess syncrepos

lib32-mesa: glproto lib32-libxshmfence lib32-libdrm lib32-llvm lib32-libxvmc lib32-libvdpau lib32-libxxf86vm lib32-libxdamage lib32-libx11 lib32-libxt lib32-wayland mesa lib32-libxshmfence syncrepos

lib32-llvm: llvm syncrepos

lib32-libxshmfence: libxshmfence syncrepos

