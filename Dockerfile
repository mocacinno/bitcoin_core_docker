
# -------------------------------
# Stage 1: Builder
# -------------------------------
FROM registry.suse.com/bci/bci-base:16.0 AS builder

# OCI Labels
LABEL org.opencontainers.image.title="Bitcoin Core Legacy Build"
LABEL org.opencontainers.image.version="0.2.0-patched"
LABEL org.opencontainers.image.source="https://github.com/mocacinno/bitcoin_core_history"
LABEL org.opencontainers.image.revision="manual-trigger-20260105"

# import Mocacinno's pubkey
RUN zypper --non-interactive ref && \
    zypper --non-interactive in -y curl ca-certificates
WORKDIR /etc/pki/rpm-gpg/
RUN curl -fsSL https://raw.githubusercontent.com/mocacinno/bitcoin_core_docker_prereqs/refs/heads/gh-pages/mocacinno_pubkey.asc -o /etc/pki/rpm-gpg/RPM-GPG-KEY-myrepo && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-myrepo

# Add custom repositories for legacy packages
RUN zypper --non-interactive ref && \
    zypper addrepo --priority 200 -f https://github.com/mocacinno/bitcoin_core_docker_prereqs/raw/refs/heads/gh-pages/x86_64/ mocacinno_x86_64 && \
    zypper addrepo --priority 200 -f https://github.com/mocacinno/bitcoin_core_docker_prereqs/raw/refs/heads/gh-pages/noarch/ mocacinno_noarch && \
    zypper --gpg-auto-import-keys ref -s

# Install build tools and dependencies
RUN zypper --non-interactive in -y curl ca-certificates gcc48 gcc48-c++ make automake makeinfo git gawk wget \
    libicu-devel mlocate vim unzip cmake xz meson patch libtool gtk-doc libatk-1_0-0 libICE-devel libSM-devel \
    libXt-devel gtk2-devel dejavu-fonts dos2unix xauth

# Set GCC 4.8 as default
ENV CC=gcc-4.8
ENV CXX=g++-4.8
RUN ln -s /usr/bin/gcc-4.8 /usr/bin/gcc && \
    ln -s /usr/bin/g++-4.8 /usr/bin/g++

# -------------------------------
# Build OpenSSL 0.9.8k
# -------------------------------
WORKDIR /src
RUN curl -fsSL https://www.openssl.org/source/openssl-0.9.8k.tar.gz -o openssl.tar.gz && \
    echo "7e7cd4f3974199b729e6e3a0af08bd4279fde0370a1120c1a3b351ab090c6101  openssl.tar.gz" | sha256sum -c - && \
    tar -xvf openssl.tar.gz && \
    cd openssl-0.9.8k && ./config && make && make install_sw && \
    ln -s /usr/local/ssl/lib/lib* /usr/lib64/

# -------------------------------
# Build Berkeley DB 4.7.25
# -------------------------------
WORKDIR /src
RUN curl -fsSL http://download.oracle.com/berkeley-db/db-4.7.25.NC.tar.gz -o db.tar.gz && \
    echo "cd39c711023ff44c01d3c8ff0323eef7318660772b24f287556e6bf676a12535  db.tar.gz" | sha256sum -c - && \
    tar -xvf db.tar.gz && \
    cd db-4.7.25.NC/build_unix && ../dist/configure --enable-cxx && \
    make -j"$(($(nproc)+1))" && make install && \
    ln -s /usr/local/BerkeleyDB.4.7/lib/* /usr/lib64/

# -------------------------------
# Build util-macros 1.3.0
# -------------------------------
WORKDIR /src
RUN curl -fsSL https://gitlab.freedesktop.org/xorg/util/macros/-/archive/util-macros-1.3.0/macros-util-macros-1.3.0.tar.gz -o util-macros.tar.gz && \
    echo "9ff621a64a92d37cdcd9b0e32186906a62b9c3e6bc78243f73b153ed1ab3b42b util-macros.tar.gz" | sha256sum -c - && \
    tar -xvf util-macros.tar.gz && \
    cd macros-util-macros-1.3.0 && \
    sed -i '24i m4_pattern_allow([AS_HELP_STRING])' configure.ac && \
    ./autogen.sh && ./configure && make && make install

# -------------------------------
# Build libxtrans 1.0.2
# -------------------------------
WORKDIR /src
RUN curl -fsSL https://gitlab.freedesktop.org/xorg/lib/libxtrans/-/archive/xtrans-1.0.2/libxtrans-xtrans-1.0.2.tar.gz -o libxtrans.tar.gz && \
    echo "7017d9028eb2def63b0b811183ac6dda3eb371ce51559db973c729db2c74d4b8 libxtrans.tar.gz" | sha256sum -c - && \
    tar -xvf libxtrans.tar.gz && \
    cd libxtrans-xtrans-1.0.2 && \
    sed -i '24i m4_pattern_allow([AS_HELP_STRING])' configure.ac && \
    ./autogen.sh && ./configure && make && make install

# -------------------------------
# Build Pango 1.24.5 + Freetype
# -------------------------------
WORKDIR /src
RUN curl -fsSL https://download.gnome.org/sources/pango/1.24/pango-1.24.5.tar.gz -o pango.tar.gz && \
    echo "0329ff38aa7030bde1da109463c6c11eff6bd6d7f8a8818be25e1704588386bb pango.tar.gz" | sha256sum -c - && \
    tar -xvf pango.tar.gz && \
    mv /usr/include/freetype2 /opt/freetype2_bak && \
    mkdir -p /usr/local/include/freetype1 /usr/local/include/freetype && \
    curl -fsSL https://github.com/LuaDist/freetype/archive/refs/heads/master.zip -o freetype.zip && \
    echo "e0b8460820ee9048720dc5932b0433ed3e08d6537bec075c290a2d3184534919 freetype.zip" | sha256sum -c - && \
    unzip freetype.zip && \
    cp -r /src/freetype-master/include/freetype/* /usr/local/include/freetype1 && \
    cp -r /src/freetype-master/include/*.h /usr/local/include/freetype1 && \
    cp -r /usr/local/include/freetype1/* /usr/local/include/freetype && \
    cd pango-1.24.5 && CPPFLAGS="-I/usr/local/include/freetype1" ./configure && \
    make -j"$(($(nproc)+1))" && make install && \
    mv /opt/freetype2_bak /usr/include/freetype2 && \
    cp -r /src/pango-1.24.5/pango/.libs/* /usr/lib64/

# -------------------------------
# Build wxWidgets 2.8.9
# -------------------------------
WORKDIR /src
RUN curl -fsSL https://github.com/wxWidgets/wxWidgets/archive/refs/tags/v2.8.9.zip -o wx.zip && \
    echo "31012f5fbeb67c48fdc0a7230e45de9cdd45ffa78f7f2fe0d3dfd589416224f1 wx.zip" | sha256sum -c - && \
    unzip wx.zip && \
    cd wxWidgets-2.8.9 && ./autogen.sh && \
    find . -type f -exec sed -i 's/GSocket/wxGSocket/g' {} \; && \
    find . -type f -exec sed -i 's/typedef struct _GSocket/typedef struct _wxGSocket/' {} \; && \
    find . -type f -exec sed -i 's/class GSocket/class wxGSocket/' {} \; && \
    CXXFLAGS="-fPIC -fpermissive" CFLAGS="-fPIC -fpermissive" ./configure --enable-unicode --enable-debug \
    --prefix=/usr/local/wxwidgets --with-gtk --enable-shared --enable-monolithic && \
    ln -s /usr/lib64/libjpeg.so.8 /usr/lib64/libjpeg8.so && \
    unlink /usr/lib64/libjpeg.so && \
    ln -s /usr/lib64/libjpeg.so.8.3.2 /usr/lib64/libjpeg.so && \
    make -j"$(($(nproc)+1))" LDFLAGS="-lpangocairo-1.0 -lX11 -lcairo -ljpeg8" && \
    make install && ldconfig

# -------------------------------
# Build Boost 1.40.0
# -------------------------------
WORKDIR /src
RUN curl -fsSL https://sourceforge.net/projects/boost/files/boost/1.40.0/boost_1_40_0.tar.gz/download -o boost.tar.gz && \
    echo "10f1ae33c9c25105554653aa7e86052e7afc9fe797c3cf188a5c8951965ae0d7 boost.tar.gz" | sha256sum -c - && \
    tar -xvf boost.tar.gz && \
    cd boost_1_40_0 && chmod +x bootstrap.sh && \
    ./bootstrap.sh && ./bjam -j"$(($(nproc)+1))" install || echo 1

# -------------------------------
# Build Bitcoin Core Legacy
# -------------------------------
WORKDIR /src
RUN curl -fsSL https://github.com/mocacinno/bitcoin_core_history/archive/refs/heads/v0.2.0_patched.zip -o bitcoin.zip && \
    echo "606e486a3d4e0e37ae3524b274a9beb8ca143cf1209dd009813df2838287a7ab bitcoin.zip" | sha256sum -c - && \
    unzip bitcoin.zip && \
    cd bitcoin_core_history-0.2.0_patched && \
    mkdir -p obj/nogui && \
    dos2unix * && \
    make -f makefile.mocacinno bitcoin CFLAGS="-I/src/wxWidgets-2.8.9/include -I/src/wxWidgets-2.8.9/lib/wx/include/gtk2-unicode-debug-2.8 -I/src/openssl-0.9.8k/include -I/src/db-4.7.25.NC/build_unix -fpermissive -D_FILE_OFFSET_BITS=64 -D__WXDEBUG__ -DWXUSINGDLL -D__WXGTK__ -pthread -march=x86-64 -mtune=generic" && \
    strip bitcoin && \
    ln -s /src/bitcoin_core_history-0.2.0_patched/bitcoin /usr/local/bin

# -------------------------------
# Stage 2: Runtime
# -------------------------------
FROM registry.suse.com/bci/bci-base:16.0

LABEL org.opencontainers.image.title="Bitcoin Core Legacy Runtime"
LABEL org.opencontainers.image.version="0.2.0-patched"
LABEL org.opencontainers.image.source="https://github.com/mocacinno/bitcoin_core_history"
LABEL org.opencontainers.image.revision="manual-trigger-20260105"

RUN zypper --non-interactive ref && \
    zypper --non-interactive in -y xauth openssl dejavu-fonts strace

RUN useradd -m -u 10001 bitcoinuser

# Copy binary and scripts
COPY --from=builder /usr/local/bin/bitcoin /usr/local/bin/
COPY --from=builder /src/wxWidgets-2.8.9/lib/libwx_gtk2ud-2.8.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libgtk-x11-2.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libgthread-2.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libSM.so.6 /usr/lib64/
COPY --from=builder /usr/lib64/libpangocairo-1.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libX11.so.6 /usr/lib64/
COPY --from=builder /usr/lib64/libcairo.so.2 /usr/lib64/
COPY --from=builder /usr/lib64/libjpeg.so.8 /usr/lib64/
COPY --from=builder /usr/lib64/libgdk-x11-2.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libatk-1.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libgdk_pixbuf-2.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libgio-2.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libpangoft2-1.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libpango-1.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libgobject-2.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libharfbuzz.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libfontconfig.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libfreetype.so.6 /usr/lib64/
COPY --from=builder /usr/lib64/libtiff.so.6 /usr/lib64/
COPY --from=builder /usr/lib64/libexpat.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libXfixes.so.3 /usr/lib64/
COPY --from=builder /usr/lib64/libgmodule-2.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libICE.so.6 /usr/lib64/
COPY --from=builder /usr/lib64/libuuid.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libpng16.so.16 /usr/lib64/
COPY --from=builder /usr/lib64/libXrender.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libxcb-render.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libxcb-shm.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libpixman-1.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libXinerama.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libXi.so.6 /usr/lib64/
COPY --from=builder /usr/lib64/libXrandr.so.2 /usr/lib64/
COPY --from=builder /usr/lib64/libXcursor.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libXcomposite.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libXdamage.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libmount.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libfribidi.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libthai.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libgraphite2.so.3 /usr/lib64/
COPY --from=builder /usr/lib64/libbrotlidec.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libjbig.so.2 /usr/lib64/
COPY --from=builder /usr/lib64/libblkid.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libdatrie.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libbrotlicommon.so.1 /usr/lib64/
COPY --from=builder /usr/share/gtk-2.0 /usr/share/gtk-2.0
COPY --from=builder /etc/fonts /etc/fonts
COPY --from=builder /usr/share/fonts /usr/share/fonts

# Copy GTK/GDK Pixbuf resources
COPY --from=builder /usr/lib64/gdk-pixbuf-2.0 /usr/lib64/gdk-pixbuf-2.0
COPY --from=builder /usr/share/icons /usr/share/icons
COPY --from=builder /usr/share/pixmaps /usr/share/pixmaps

# Copy charset and gconv modules
COPY --from=builder /usr/lib64/gconv /usr/lib64/gconv


# Rebuild GDK Pixbuf loaders cache
COPY --from=builder /usr/bin/gdk-pixbuf-query-loaders-64 /usr/bin
RUN gdk-pixbuf-query-loaders-64 > /usr/lib64/gdk-pixbuf-2.0/2.10.0/loaders.cache

# Ensure wxWidgets libraries are found
ENV LD_LIBRARY_PATH="/usr/local/wxwidgets/lib"
RUN ldconfig

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/init.sh

# make directorys
RUN mkdir -p /home/bitcoinuser/.bitcoin && \
    chown -R bitcoinuser:users /home/bitcoinuser/.bitcoin

# Persistent blockchain data
VOLUME ["/home/bitcoinuser/.bitcoin"]


USER bitcoinuser
WORKDIR /home/bitcoinuser


# Define entrypoint script as the container's ENTRYPOINT
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Optional CMD for additional arguments (e.g., bitcoind flags)
CMD []
