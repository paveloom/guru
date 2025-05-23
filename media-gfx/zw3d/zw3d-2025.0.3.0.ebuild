# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

MY_PGK_NAME="com.zwsoft.zw3d2025"
inherit unpacker xdg

DESCRIPTION="CAD/CAM software for 3D design and processing"
HOMEPAGE="https://www.zwsoft.cn/product/zw3d/linux"
SRC_URI="signed_com.zwsoft.zw3d2025_2025.0.3.0_amd64.deb"

S="${WORKDIR}"

LICENSE="all-rights-reserved"
SLOT="0"
KEYWORDS="-* ~amd64"

RESTRICT="strip mirror bindist fetch"

RDEPEND="
	app-arch/bzip2
	app-arch/xz-utils
	app-text/djvu
	dev-db/sqlite:3
	dev-libs/glib:2
	dev-libs/libpcre
	dev-libs/libxml2
	dev-qt/qtcore:5
	dev-qt/qtgui:5
	dev-qt/qtnetwork:5
	dev-qt/qtprintsupport:5
	dev-qt/qtsvg:5
	media-fonts/noto-cjk
	media-gfx/imagemagick
	media-libs/freetype
	media-libs/jbigkit
	media-libs/libglvnd
	media-libs/libpng
	media-libs/opencollada
	media-libs/tiff
	media-libs/tiff-compat:4
	net-libs/zeromq
	sys-libs/zlib
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3
	x11-libs/libX11
	x11-libs/libxcb
	x11-libs/libXcomposite
	x11-libs/libXext
	x11-libs/libxkbcommon
	x11-libs/libXmu
	x11-libs/libXrender
	x11-libs/libXt
	x11-libs/pango
"

DEPEND="${RDEPEND}"

BDEPEND="
	dev-util/bbe
	dev-util/patchelf
"

QA_PREBUILT="*"

src_install() {
	# Set RPATH for preserve-libs handling
	pushd "${S}"/opt/apps/${MY_PGK_NAME}/files || die
	local x
	for x in $(find) ; do
		# Use \x7fELF header to separate ELF executables and libraries
		[[ -f ${x} && $(od -t x1 -N 4 "${x}") == *"7f 45 4c 46"* ]] || continue
		local RPATH_ROOT="/opt/apps/${MY_PGK_NAME}/files"
		local RPATH_S="${RPATH_ROOT}/:${RPATH_ROOT}/xlator/:${RPATH_ROOT}/xlator/InterOp/:${RPATH_ROOT}/libqt/:${RPATH_ROOT}/libqt/plugins/designer/:${RPATH_ROOT}/lib3rd/:/usr/lib64/"
		patchelf --set-rpath "${RPATH_S}" "${x}" || \
			die "patchelf failed on ${x}"
		patchelf --replace-needed libjbig.so.0 libjbig.so "${x}" || \
			die "patchelf failed on ${x}"
		patchelf --replace-needed libwebp.so.6 libwebp.so "${x}" || \
			die "patchelf failed on ${x}"
	done
	popd || die

	# Use system libtiff
	rm -rf "${S}"/opt/apps/${MY_PGK_NAME}/files/lib3rd/libtiff* || die

	# Fix desktop files
	sed -E -i "s/^Icon=.*$/Icon=${MY_PGK_NAME}/g" "${S}/usr/share/applications/${MY_PGK_NAME}.desktop" || die
	sed -E -i "s/Application;//g" "${S}/usr/share/applications/${MY_PGK_NAME}.desktop" || die

	# Add zw3d command
	mkdir -p "${S}"/usr/bin/ || die

	ln -s /opt/apps/${MY_PGK_NAME}/files/zw3drun.sh "${S}"/usr/bin/zw3d || die

	# Fix zw3d startup file
cat >> insert.txt <<- EOF || die
unset WAYLAND_DISPLAY
export XDG_SESSION_TYPE=x11
export QT_QPA_PLATFORM=xcb
export QT_AUTO_SCREEN_SCALE_FACTOR=0
export QT_STYLE_OVERRIDE=fusion
export IBUS_USE_PORTAL=1
	EOF

	sed -i \
		-e '/export LD_LIBRARY_PATH/r insert.txt' \
		"${S}"/opt/apps/${MY_PGK_NAME}/files/zw3drun.sh || die

	sed -E -i "s|^script_dir=.*$|script_dir=/opt/apps/${MY_PGK_NAME}/files|g" \
		"${S}"/opt/apps/${MY_PGK_NAME}/files/zw3drun.sh || die

	# Use system libraries
	rm -rf "${S}"/opt/apps/${MY_PGK_NAME}/files/lib3rd/libfreetype* || die

	# Fix coredump while draw 2D sketch due to not find fonts
	# media-fonts/noto-cjk is required
	# and should use /usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc
	local MY_FONT_PATH_OLD="/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"
	local MY_FONT_PATH_NEW="//////usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc"
	bbe -e "s|${MY_FONT_PATH_OLD}|${MY_FONT_PATH_NEW}|" "${S}/opt/apps/${MY_PGK_NAME}/files/libdisp.so" \
		> "${S}/opt/apps/${MY_PGK_NAME}/files/libdisp.so.tmp" && \
	mv "${S}/opt/apps/${MY_PGK_NAME}/files/libdisp.so.tmp" "${S}/opt/apps/${MY_PGK_NAME}/files/libdisp.so" || die

	# Install package and fix permissions
	insinto /opt/apps
	doins -r opt/apps/${MY_PGK_NAME}
	insinto /usr
	doins -r usr/*

	fperms 0755 /opt/apps/${MY_PGK_NAME}/files/zw3drun.sh

	pushd "${S}" || die
	for x in $(find "opt/apps/${MY_PGK_NAME}") ; do
		# Fix shell script permissions
		[[ "${x: -3}" == ".sh" ]] && fperms 0755 "/${x}"
		# Use \x7fELF header to separate ELF executables and libraries
		[[ -f ${x} && $(od -t x1 -N 4 "${x}") == *"7f 45 4c 46"* ]] && fperms 0755 "/${x}"
	done
	popd || die
}

pkg_nofetch() {
	einfo "Please download the installation file ${SRC_URI}"
	einfo "and place the file in your DISTDIR directory."
	einfo "Note that to actually run and use ${P} you need a valid license."
}
