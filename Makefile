REPO=xorg-git
LOCAL=/home/packages/$(REPO)
REMOTE=74.72.157.140:/home/serkan/public_html/arch/$(REPO)

PWD=$(shell pwd)
DIRS=$(shell ls | grep -v Makefile*)
DATE=$(shell date +"%Y%m%d")
TIME=$(shell date +"%H%M")
PACMAN=yaourt
PKGEXT=pkg.tar.xz

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

show:
	@echo $(DATE)
	@echo $(DIRS)

build: $(DIRS)

test:
	_gitname=$$(grep -R '^_gitname' $(PWD)/$*/PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') && \
	echo $$_gitname

%/built:
	@_gitname=$$(grep -R '^_gitname' $(PWD)/$*/PKGBUILD | sed -e 's/_gitname=//' -e "s/'//g" -e 's/"//g') && \
	if [ -d $(PWD)/$*/src/$$_gitname/.git ]; then \
		sed -i "s/^pkgver=[^ ]*/pkgver=$(DATE)/" "$(PWD)/$*/PKGBUILD" ; \
		sed -i "s/^pkgrel=[^ ]*/pkgrel=$(TIME)/" "$(PWD)/$*/PKGBUILD" ; \
	fi ; \
	rm -f $(PWD)/$*/*$(PKGEXT) ; \
	cd $* ; makepkg -f || exit 1 && cd $(PWD) && \
	rm -f $(addsuffix *, $(addprefix $(LOCAL)/, $(shell grep -R '^pkgname' $*/PKGBUILD | sed -e 's/pkgname=//' -e 's/(//g' -e 's/)//g' -e "s/'//g" -e 's/"//g'))) && \
	rm -f $(addsuffix /built, $(shell grep $* Makefile | cut -d':' -f1)) && \
	repo-remove $(LOCAL)/$(REPO).db.tar.gz $(shell grep -R '^pkgname' $*/PKGBUILD | sed -e 's/pkgname=//' -e 's/(//g' -e 's/)//g' -e "s/'//g" -e 's/"//g') ; \
	$(PACMAN) -U --noconfirm $*/*$(PKGEXT) && \
	mv $*/*$(PKGEXT) $(LOCAL) && \
	repo-add $(LOCAL)/$(REPO).db.tar.gz $(addsuffix *, $(addprefix $(LOCAL)/, $(shell grep -R '^pkgname' $*/PKGBUILD | sed -e 's/pkgname=//' -e 's/(//g' -e 's/)//g' -e "s/'//g" -e 's/"//g'))) && \
	if [ -d $(PWD)/$*/src/$$_gitname/.git ]; then \
		cd $(PWD)/$*/src/$$_gitname && \
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
			git clone $$_gitroot $(PWD)/$@/src/$$_gitname ; \
		fi ; \
		$(MAKE) $@/built ; \
	fi ; \

PROTOS= \
	bigreqsproto-git \
	compositeproto-git \
	damageproto-git \
	dmxproto-git \
	dri2proto-git \
	fixesproto-git \
	fontsproto-git \
	glproto-git \
	inputproto-git \
	kbproto-git \
	randrproto-git \
	recordproto-git \
	renderproto-git \
	resourceproto-git \
	scrnsaverproto-git \
	videoproto-git \
	xcb-proto-git \
	xcmiscproto-git \
	xextproto-git \
	xf86dgaproto-git \
	xf86driproto-git \
	xineramaproto-git \
	xproto-git

$(PROTOS): xorg-util-macros-git

libx11-git: libxcb-git xproto-git kbproto-git xorg-util-macros-git xextproto-git xtrans-git inputproto-git

libxext-git: $(PROTOS) libx11-git

libxrender-git: libx11-git renderproto-git

libxrandr-git: libxext-git libxrender-git randrproto-git

libxcb-git: $(PROTOS) libxdmcp-git libxau-git

libxdmcp-git: $(PROTOS)

libxau-git: $(PROTOS)

libxi-git: $(PROTOS) libxext-git

libxtst-git: $(PROTOS) libxext-git libxi-git

libxt: libsm-git libx11-git

libsm-git: xtrans-git

libxres-git: $(PROTOS) libxext-git

libdmx-git: $(PROTOS) libxext-git

libxfixes-git: $(PROTOS) libx11-git

libxdamage-git: $(PROTOS) libxfixes-git

libxcomposite-git: libxfixes-git compositeproto-git xorg-util-macros-git

libxxf86vm-git: $(PROTOS) libxext-git

libice: xproto-git xtrans-git

cairo-git: libxrender-git pixman-git

mesa-git: $(PROTOS) libdrm-git llvm-amdgpu-git wayland-git libxfixes-git libxdamage-git libxxf86vm-git

lib32-mesa-git: $(PROTOS) lib32-libdrm-git lib32-llvm-amdgpu-git lib32-wayland-git

wayland-git: libdrm-git

lib32-wayland-git: lib32-libdrm-git

weston-git: mesa-git libxkbcommon-git pixman-git cairo-git glu-git

glu-git: mesa-git

mesa-demos-git: mesa-git

libxv-git: libxext-git videoproto-git

libfontenc-git: xproto-git

libxfont-git: libfontenc-git xproto-git fontsproto-git xorg-util-macros-git xtrans-git

libxmu-git: libxext-git libxt-git xorg-util-macros-git

libxpm-git: libxt-git libxext-git xorg-util-macros-git

libxaw-git: libxmu-git libxpm-git xorg-util-macros-git

xorg-font-util-git: xorg-util-macros-git

xorg-setxkbmap-git: libxkbfile-git xorg-util-macros-git

xorg-server-git: $(PROTOS) libdmx-git libdrm-git libpciaccess-git libx11-git libxau-git libxaw-git libxdmcp-git libxext-git libxfixes-git libxfont-git libxi-git libxkbfile-git libxmu-git libxrender-git libxres-git libxtst-git libxv-git mesa-git pixman-git xkeyboard-config-git xorg-font-util-git xorg-setxkbmap-git xorg-util-macros-git xorg-xkbcomp-git xtrans-git

xorg-xauth-git: libxmu-git xorg-util-macros-git

xorg-xrandr-git: libxrandr-git libx11-git xorg-util-macros-git

xorg-xprop-git: libx11-git xorg-util-macros-git

xorg-xwininfo-git: libxcb-git libx11-git xorg-util-macros-git

xf86-input-evdev-git: xorg-server-git

xf86-input-synaptics-git: xorg-server-git

xf86-video-ati-git: $(PROTOS) xorg-server-git glamor-git libdrm-git libpciaccess-git pixman-git

glamor-git: xorg-server-git mesa-git

compton-git: libx11-git libxcomposite-git libxdamage-git libxext-git libxrender-git xproto-git xorg-xprop-git xorg-xwininfo-git libxrandr-git
