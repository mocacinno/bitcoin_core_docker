FROM registry.suse.com/bci/bci-base:15.7 AS builder

RUN zypper --non-interactive ref && \
    zypper --non-interactive in -y curl ca-certificates
WORKDIR /etc/pki/rpm-gpg/
RUN curl -fsSL https://raw.githubusercontent.com/mocacinno/bitcoin_core_docker_prereqs/refs/heads/gh-pages/mocacinno_pubkey.asc -o /etc/pki/rpm-gpg/RPM-GPG-KEY-myrepo && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-myrepo

RUN zypper addrepo -f https://github.com/mocacinno/bitcoin_core_docker_prereqs/raw/refs/heads/gh-pages/x86_64/ mocacinno_x86_64 && \
    zypper addrepo -f https://github.com/mocacinno/bitcoin_core_docker_prereqs/raw/refs/heads/gh-pages/noarch/ mocacinno_noarch
RUN zypper --gpg-auto-import-keys ref -s && \
    zypper --non-interactive install gcc48 gcc48-c++ make automake makeinfo git gawk wget libicu-devel mlocate vim unzip cmake xz meson patch libtool gtk-doc libatk-1_0-0 libICE-devel libSM-devel libXt-devel gtk2 gtk2-devel dos2unix


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


#boost 1.57.0
WORKDIR /
RUN wget https://sourceforge.net/projects/boost/files/boost/1.57.0/boost_1_57_0.tar.gz/download -O boost_1_57_0.tar.gz && \
    tar -xvf boost_1_57_0.tar.gz
ENV BOOST_ROOT=/boost_1_57_0
WORKDIR /boost_1_57_0
RUN chmod +x bootstrap.sh  && \
    ./bootstrap.sh  && \
    ./b2  -j"$(($(nproc) + 1))" && \
    ./b2 install  && \
    ./b2 headers  && \
    ln -s /boost_1_57_0/stage/lib/* /usr/lib64


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


#wxwidgets 2.9.5
WORKDIR /
RUN wget https://github.com/wxWidgets/wxWidgets/archive/refs/tags/v2.9.5.zip && \
    unzip v2.9.5.zip
WORKDIR /wxWidgets-2.9.5
RUN ./autogen.sh && \
    ./configure && \
    make -j"$(($(nproc) + 1))" && \
    make install


#bitcoin v0.3.1
WORKDIR /
RUN wget https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.3.1.zip && \
    unzip v0.3.1.zip
WORKDIR /bitcoin-0.3.1
RUN find /bitcoin-0.3.1/ -type f -exec dos2unix {} + && \
    mkdir -p obj/nogui && \
    ln -s /usr/local/lib/libwx_baseu-2.9.so /usr/lib64/libwx_baseud-2.9.so && \
    make -j"$(($(nproc) + 1))" -f makefile.unix bitcoind CFLAGS="-I/usr/local/lib/wx/include/gtk2-unicode-2.9 -I/usr/local/include/wx-2.9 -I/db-4.7.25.NC/build_unix -I/boost_1_57_0 -I/openssl-0.9.8k/include" && \
    strip bitcoind



FROM registry.suse.com/bci/bci-minimal:15.7
COPY --from=builder /bitcoin-0.3.1/bitcoind /usr/local/bin
COPY --from=builder /boost_1_57_0/stage/lib/libboost_system.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_filesystem.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_program_options.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_thread.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_chrono.so.1.57.0 /usr/lib64/
COPY --from=builder /usr/local/lib/libwx_baseu-2.9.so.5 /usr/lib64/
COPY --from=builder /usr/lib64/libgthread-2.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libglib-2.0.so.0 /usr/lib64/


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
LABEL org.opencontainers.image.revision="manual-trigger-20260105"
ENTRYPOINT ["/entrypoint.sh"]
