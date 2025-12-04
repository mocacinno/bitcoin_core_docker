FROM registry.suse.com/bci/bci-base:16.0 AS builder

RUN zypper --non-interactive ref && \
    zypper --non-interactive in -y curl ca-certificates
WORKDIR /etc/pki/rpm-gpg/
RUN curl -fsSL https://raw.githubusercontent.com/mocacinno/bitcoin_core_docker_prereqs/refs/heads/gh-pages/mocacinno_pubkey.asc -o /etc/pki/rpm-gpg/RPM-GPG-KEY-myrepo && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-myrepo

RUN zypper addrepo --priority 200 -f https://github.com/mocacinno/bitcoin_core_docker_prereqs/raw/refs/heads/gh-pages/x86_64/ mocacinno_x86_64 && \
    zypper addrepo --priority 200 -f https://github.com/mocacinno/bitcoin_core_docker_prereqs/raw/refs/heads/gh-pages/noarch/ mocacinno_noarch
RUN zypper --gpg-auto-import-keys ref -s && \
    zypper --non-interactive install gcc48 gcc48-c++ make automake makeinfo git gawk wget libicu-devel mlocate vim unzip cmake xz meson patch libtool gtk-doc libatk-1_0-0 libICE-devel libSM-devel libXt-devel gtk2-devel


#gcc 4.8
ENV CC=gcc-4.8
ENV CXX=g++-4.8
ENV PERL5LIB=.
RUN ln -s /usr/bin/gcc-4.8 /usr/bin/gcc && \
    ln -s /usr/bin/g++-4.8 /usr/bin/g++
   

#berkelydb 4.7.25
WORKDIR /
RUN wget http://download.oracle.com/berkeley-db/db-4.7.25.NC.tar.gz && \
    tar -xvf db-4.7.25.NC.tar.gz
WORKDIR /db-4.7.25.NC/build_unix
RUN ../dist/configure --enable-cxx && \
    make -j"$(($(nproc) + 1))" && make install && \
    ln -s /usr/local/BerkeleyDB.4.7/lib/* /usr/lib64/

#boost 1.40.0
WORKDIR /
RUN wget https://sourceforge.net/projects/boost/files/boost/1.38.0/boost_1_38_0.tar.gz/download -O boost_1_38_0.tar.gz && \
    tar -xvf boost_1_38_0.tar.gz
ENV BOOST_ROOT=/boost_1_38_0
WORKDIR /boost_1_38_0
RUN ./configure && \
	make -j"$(($(nproc) + 1))" && \
	make install



#openssl 0.9.8k
WORKDIR /
RUN wget https://www.openssl.org/source/openssl-0.9.8k.tar.gz && \
    tar -xvf openssl-0.9.8k.tar.gz
WORKDIR /openssl-0.9.8k
RUN ./config && \
    make && \
    make install_sw && \
    ln -s /usr/local/ssl/lib/lib* /usr/lib64/


#util macros 1.3.0
WORKDIR /
RUN wget https://gitlab.freedesktop.org/xorg/util/macros/-/archive/util-macros-1.3.0/macros-util-macros-1.3.0.tar.gz && \
    tar -xvf macros-util-macros-1.3.0.tar.gz
WORKDIR /macros-util-macros-1.3.0
RUN sed -i '24i m4_pattern_allow([AS_HELP_STRING])' configure.ac  && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install


#libXtrans 1.0.2
WORKDIR / 
RUN wget https://gitlab.freedesktop.org/xorg/lib/libxtrans/-/archive/xtrans-1.0.2/libxtrans-xtrans-1.0.2.tar.gz && \
    tar -xvf libxtrans-xtrans-1.0.2.tar.gz
WORKDIR /libxtrans-xtrans-1.0.2
RUN sed -i '24i m4_pattern_allow([AS_HELP_STRING])' configure.ac && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install


#pango 1.24.5
WORKDIR /
RUN wget https://download.gnome.org/sources/pango/1.24/pango-1.24.5.tar.gz && \
    tar -xvf pango-1.24.5.tar.gz && \
    mv /usr/include/freetype2 /opt/freetype2_bak && \
    mkdir -p /usr/local/include/freetype1 && \
    mkdir -p /usr/local/include/freetype && \
    wget https://github.com/LuaDist/freetype/archive/refs/heads/master.zip && \
    unzip master.zip && \
    cp -r /freetype-master/include/freetype/* /usr/local/include/freetype1 && \
    cp -r /freetype-master/include/*.h /usr/local/include/freetype1 && \
    cp -r /usr/local/include/freetype1/* /usr/local/include/freetype
WORKDIR /pango-1.24.5
RUN CPPFLAGS="-I/usr/local/include/freetype1" ./configure && \
    make -j"$(($(nproc) + 1))" && \
    make install && \
    mv /opt/freetype2_bak /usr/include/freetype2 && \
    cp -r /pango-1.24.5/pango/.libs/* /usr/lib64/


#wxwidgets 2.9.0 changed vs bitcoin v0.2.6
WORKDIR /
RUN wget https://github.com/wxWidgets/wxWidgets/archive/refs/tags/v2.9.0.zip && \
    unzip v2.9.0.zip
WORKDIR /wxWidgets-2.9.0
RUN ./autogen.sh && \
    CXXFLAGS="-fPIC -fpermissive" CFLAGS="-fPIC" \
    ./configure \
        --with-gtk \
        --enable-unicode \
#        --enable-debug \
        --enable-shared \
        --prefix=/usr/local/wxwidgets && \
    ln -s /usr/lib64/libjpeg.so.8 /usr/lib64/libjpeg8.so && \
    unlink /usr/lib64/libjpeg.so && \
    ln -s /usr/lib64/libjpeg.so.8.3.2 /usr/lib64/libjpeg.so && \
    CXXFLAGS="-fPIC -fpermissive" CFLAGS="-fPIC" \
    make -j"$(($(nproc) + 1))" \
    LDFLAGS="-lpangocairo-1.0 -lX11 -lcairo -ljpeg8" && \
    make install && \
    cp -R /wxWidgets-2.9.0/lib/* /usr/lib64/ && \
    ldconfig
ENV LD_LIBRARY_PATH=/wxWidgets-2.9.0/lib/

#bitcoin v0.2.8
WORKDIR /
RUN wget https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.2.8.zip && \
    unzip v0.2.8.zip
WORKDIR /bitcoin-0.2.8
RUN mkdir -p obj/nogui && \
    zypper --non-interactive install dos2unix && \
    dos2unix makefile.unix && \
    sed -i '24s/-mt//g' makefile.unix && \
    sed -i 's/wx_baseud-2\.9/wx_baseu-2\.9/g' makefile.unix && \
    ln -sf /usr/local/lib/libboost_system-gcc48-mt.a       /usr/local/lib/libboost_system.a && \
    ln -sf /usr/local/lib/libboost_filesystem-gcc48-mt.a   /usr/local/lib/libboost_filesystem.a && \
    ln -sf /usr/local/lib/libboost_system-gcc48-mt.so      /usr/local/lib/libboost_system.so && \
    ln -sf /usr/local/lib/libboost_filesystem-gcc48-mt.so  /usr/local/lib/libboost_filesystem.so && \
    make -f makefile.unix bitcoind CFLAGS="-fpermissive -I/openssl-0.9.8k/include -I/db-4.7.25.NC/build_unix -I/wxWidgets-2.9.0/include -I/wxWidgets-2.9.0/lib/wx/include/gtk2-unicode-release-2.9 -I/boost_1_38_0"

FROM registry.suse.com/bci/bci-micro:latest
COPY --from=builder /bitcoin-0.2.8/bitcoind /usr/local/bin
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

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 8332 8333 15332 15333
RUN echo 'bitcoinuser:x:10001:10001:Bitcoin User:/home/bitcoinuser:/bin/sh' >> /etc/passwd \
 && echo 'bitcoinuser:x:10001:' >> /etc/group \
 && mkdir -p /home/bitcoinuser \
 && chown -R 10001:10001 /home/bitcoinuser
COPY bitcoin.conf /home/bitcoinuser/.bitcoin/bitcoin.conf
RUN chown -R bitcoinuser:bitcoinuser /home/bitcoinuser
USER bitcoinuser
LABEL org.opencontainers.image.revision="manual-trigger-20251201"
LABEL waitforfinish="true"
ENTRYPOINT ["/entrypoint.sh"]
