
# -------------------------------
# Stage 1: Builder
# -------------------------------
FROM registry.suse.com/bci/bci-base:16.0 AS builder

LABEL org.opencontainers.image.title="Bitcoin Core Legacy Build"
LABEL org.opencontainers.image.version="v0.2.8"
LABEL org.opencontainers.image.source="https://github.com/mocacinno/bitcoin_core_history"
LABEL org.opencontainers.image.revision="manual-trigger-20251208a"

# Import GPG key for custom repos
RUN zypper --non-interactive ref && \
    zypper --non-interactive in -y curl ca-certificates
WORKDIR /etc/pki/rpm-gpg/
RUN curl -fsSL https://raw.githubusercontent.com/mocacinno/bitcoin_core_docker_prereqs/refs/heads/gh-pages/mocacinno_pubkey.asc \
    -o /etc/pki/rpm-gpg/RPM-GPG-KEY-myrepo && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-myrepo

# Add custom repositories
RUN zypper addrepo --priority 200 -f https://github.com/mocacinno/bitcoin_core_docker_prereqs/raw/refs/heads/gh-pages/x86_64/ mocacinno_x86_64 && \
    zypper addrepo --priority 200 -f https://github.com/mocacinno/bitcoin_core_docker_prereqs/raw/refs/heads/gh-pages/noarch/ mocacinno_noarch && \
    zypper --gpg-auto-import-keys ref -s

# Install build tools and dependencies
RUN zypper --non-interactive in -y gcc48 gcc48-c++ make automake makeinfo git gawk wget \
    libicu-devel unzip cmake xz meson patch libtool gtk-doc libatk-1_0-0 libICE-devel libSM-devel \
    libXt-devel gtk2-devel dejavu-fonts dos2unix xauth

# Set GCC 4.8 as default
ENV CC=gcc-4.8
ENV CXX=g++-4.8
ENV PERL5LIB=.
RUN ln -s /usr/bin/gcc-4.8 /usr/bin/gcc && \
    ln -s /usr/bin/g++-4.8 /usr/bin/g++

WORKDIR /src

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
# Build Boost 1.38
# -------------------------------
WORKDIR /src
RUN curl -fsSL https://sourceforge.net/projects/boost/files/boost/1.38.0/boost_1_38_0.tar.gz/download -o boost.tar.gz && \
	echo "ff8c3fc932b21453ca31d28903419617f41b2110aba341256eb31be3435843af boost.tar.gz" | sha256sum -c - && \
    tar -xvf boost.tar.gz && \
	cd boost_1_38_0 && \
	./configure && \
	make -j"$(($(nproc) + 1))" && \
	make install
ENV BOOST_ROOT=/src/boost_1_38_0



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
# Build libXtrans 1.0.2
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
# Build wxWidgets 2.9.0
# -------------------------------
WORKDIR /src
RUN curl -fsSL https://github.com/wxWidgets/wxWidgets/archive/refs/tags/v2.9.0.zip -o wx.zip && \
    echo "ecb5aea6d67740145f10e956e85e3d3b66819722642c7f32440bd7a502dc1355 wx.zip" | sha256sum -c - && \
    unzip wx.zip && \
    cd wxWidgets-2.9.0 && ./autogen.sh && \
    CXXFLAGS="-fPIC -fpermissive" CFLAGS="-fPIC" ./configure --with-gtk --enable-unicode --enable-shared --prefix=/usr/local/wxwidgets && \
    ln -s /usr/lib64/libjpeg.so.8 /usr/lib64/libjpeg8.so && \
    unlink /usr/lib64/libjpeg.so && \
    ln -s /usr/lib64/libjpeg.so.8.3.2 /usr/lib64/libjpeg.so && \
    CXXFLAGS="-fPIC -fpermissive" CFLAGS="-fPIC" make -j"$(($(nproc) + 1))" LDFLAGS="-lpangocairo-1.0 -lX11 -lcairo -ljpeg8" && \
    make install && cp -R /src/wxWidgets-2.9.0/lib/* /usr/lib64/ && ldconfig
ENV LD_LIBRARY_PATH=/src/wxWidgets-2.9.0/lib/

# -------------------------------
# Build Bitcoin Core v0.2.8
# -------------------------------
WORKDIR /src
RUN curl -fsSL https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.2.8.zip -o bitcoin.zip && \
	echo "fdfa8fffb1ce53c8c667651a7f2cc92e80227dafb132796fb149635ffa66acdc bitcoin.zip" | sha256sum -c - && \
	unzip bitcoin.zip && \
	cd /src/bitcoin-0.2.8 && \
	mkdir -p obj/nogui && \
    dos2unix makefile.unix && \
    sed -i '24s/-mt//g' makefile.unix && \
    sed -i 's/wx_baseud-2\.9/wx_baseu-2\.9/g' makefile.unix && \
    ln -sf /usr/local/lib/libboost_system-gcc48-mt.a       /usr/local/lib/libboost_system.a && \
    ln -sf /usr/local/lib/libboost_filesystem-gcc48-mt.a   /usr/local/lib/libboost_filesystem.a && \
    ln -sf /usr/local/lib/libboost_system-gcc48-mt.so      /usr/local/lib/libboost_system.so && \
    ln -sf /usr/local/lib/libboost_filesystem-gcc48-mt.so  /usr/local/lib/libboost_filesystem.so && \
    make -f makefile.unix bitcoind CFLAGS="-fpermissive -I/src/openssl-0.9.8k/include -I/src/db-4.7.25.NC/build_unix -I/src/wxWidgets-2.9.0/include -I/src/wxWidgets-2.9.0/lib/wx/include/gtk2-unicode-release-2.9 -I/src/boost_1_38_0" && \
	strip bitcoind && \
	ln -s /src/bitcoin-0.2.8/bitcoind /usr/local/bin
	

# -------------------------------
# Stage 2: Runtime
# -------------------------------

FROM registry.suse.com/bci/bci-micro:latest

LABEL org.opencontainers.image.title="Bitcoin Core Legacy Runtime"
LABEL org.opencontainers.image.version="v0.2.8"
LABEL org.opencontainers.image.source="https://github.com/mocacinno/bitcoin_core_history"
LABEL org.opencontainers.image.revision="manual-trigger-20251208"

COPY --from=builder /src/bitcoin-0.2.8/bitcoind /usr/local/bin
COPY --from=builder /usr/lib64/libwx_baseu-2.9.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libgthread-2.0.so.0 /usr/lib64/
COPY --from=builder /usr/local/lib/libpangocairo-1.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libX11.so.6 /usr/lib64/
COPY --from=builder /usr/lib64/libcairo.so.2 /usr/lib64/
COPY --from=builder /usr/lib64/libjpeg.so.8 /usr/lib64/
COPY --from=builder /usr/lib64/libz.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libglib-2.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libpangoft2-1.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libpango-1.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libgobject-2.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libgmodule-2.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libfontconfig.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libfreetype.so.6 /usr/lib64/
COPY --from=builder /usr/lib64/libpng16.so.16 /usr/lib64/
COPY --from=builder /usr/lib64/libxcb.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libXext.so.6 /usr/lib64/
COPY --from=builder /usr/lib64/libXrender.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libxcb-render.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libxcb-shm.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libpixman-1.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libgio-2.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libharfbuzz.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libfribidi.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libthai.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libffi.so.8 /usr/lib64/
COPY --from=builder /usr/lib64/libexpat.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libbz2.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libbrotlidec.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libXau.so.6 /usr/lib64/
COPY --from=builder /usr/lib64/libmount.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libgraphite2.so.3 /usr/lib64/
COPY --from=builder /usr/lib64/libdatrie.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libbrotlicommon.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libblkid.so.1 /usr/lib64/
COPY --from=builder /usr/lib64/libeconf.so.0 /usr/lib64/

# Copy scripts
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/init.sh
RUN mkdir -p /home/bitcoinuser/.bitcoin
VOLUME ["/home/bitcoinuser/.bitcoin"]


RUN echo 'bitcoinuser:x:10001:10001:Bitcoin User:/home/bitcoinuser:/bin/sh' >> /etc/passwd \
 && echo 'bitcoinuser:x:10001:' >> /etc/group \
 && mkdir -p /home/bitcoinuser \
 && chown -R 10001:10001 /home/bitcoinuser
RUN chown -R bitcoinuser:bitcoinuser /home/bitcoinuser
RUN chown -R bitcoinuser:bitcoinuser /home/bitcoinuser/.bitcoin
USER bitcoinuser
WORKDIR /home/bitcoinuser

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD []
