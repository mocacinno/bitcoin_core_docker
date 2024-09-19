FROM registry.suse.com/bci/bci-base:15.6 AS builder

RUN zypper addrepo https://download.opensuse.org/repositories/devel:gcc/SLE-15/devel:gcc.repo && \
    zypper addrepo https://download.opensuse.org/repositories/home:MaxxedSUSE:Compiler-Tools-15.6/15.6/home:MaxxedSUSE:Compiler-Tools-15.6.repo && \
    zypper addrepo https://download.opensuse.org/repositories/devel:libraries:c_c++/SLE_12_SP5/devel:libraries:c_c++.repo && \
    zypper addrepo https://download.opensuse.org/repositories/home:steffens:branches:Application:Geo:qgis/SLE_11_SP4/home:steffens:branches:Application:Geo:qgis.repo && \
    zypper --gpg-auto-import-keys ref -s && \
    zypper --non-interactive install pango-devel pango-tools && \
    zypper --non-interactive install gcc48 gcc48-c++ make automake makeinfo git gawk wget libicu-devel mlocate vim unzip cmake xz meson patch libtool gtk-doc libatk-1_0-0 libICE-devel libSM-devel libXt-devel gtk2 gtk2-devel
ENV CC=gcc-4.8
ENV CXX=g++-4.8
ENV PERL5LIB=.
RUN ln -s /usr/bin/gcc-4.8 /usr/bin/gcc && \
    ln -s /usr/bin/g++-4.8 /usr/bin/g++


WORKDIR /
RUN wget https://www.openssl.org/source/openssl-0.9.8k.tar.gz && \
    tar -xvf openssl-0.9.8k.tar.gz
WORKDIR /openssl-0.9.8k
RUN ./config && \
    make && \
    make install_sw && \
    ln -s /usr/local/ssl/lib/lib* /usr/lib64/


WORKDIR /
RUN wget http://download.oracle.com/berkeley-db/db-4.7.25.NC.tar.gz && \
    tar -xvf db-4.7.25.NC.tar.gz
WORKDIR /db-4.7.25.NC/build_unix
RUN ../dist/configure --enable-cxx && \
    make -j"$(($(nproc) + 1))" && make install && \
    ln -s /usr/local/BerkeleyDB.4.7/lib/* /usr/lib64/


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


WORKDIR /
RUN wget https://gitlab.freedesktop.org/xorg/util/macros/-/archive/util-macros-1.3.0/macros-util-macros-1.3.0.tar.gz && \
    tar -xvf macros-util-macros-1.3.0.tar.gz
WORKDIR /macros-util-macros-1.3.0
RUN sed -i '24i m4_pattern_allow([AS_HELP_STRING])' configure.ac  && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install


WORKDIR / 
RUN wget https://gitlab.freedesktop.org/xorg/lib/libxtrans/-/archive/xtrans-1.0.2/libxtrans-xtrans-1.0.2.tar.gz && \
    tar -xvf libxtrans-xtrans-1.0.2.tar.gz
WORKDIR /libxtrans-xtrans-1.0.2
RUN sed -i '24i m4_pattern_allow([AS_HELP_STRING])' configure.ac && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install


WORKDIR /
RUN wget https://github.com/wxWidgets/wxWidgets/archive/refs/tags/v2.9.5.zip && \
    unzip v2.9.5.zip
WORKDIR /wxWidgets-2.9.5
RUN ./autogen.sh && \
    ./configure && \
    make -j"$(($(nproc) + 1))" && \
    make install


WORKDIR /
RUN wget https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.2.8.zip && \
    unzip v0.2.8.zip
WORKDIR /bitcoin-0.2.8
RUN zypper --non-interactive install dos2unix && \
    find /bitcoin-0.2.8/ -type f -exec dos2unix {} + && \
    mkdir -p obj/nogui && \
    ln -s /usr/local/lib/libwx_baseu-2.9.so /usr/lib64/libwx_baseud-2.9.so && \
    sed -i '24s/-mt//g' makefile.unix && \
    make -j"$(($(nproc) + 1))" -f makefile.unix bitcoind CFLAGS="-I/usr/local/lib/wx/include/gtk2-unicode-2.9 -I/usr/local/include/wx-2.9 -I/db-4.7.25.NC/build_unix -I/boost_1_57_0 -I/openssl-0.9.8k/include" && \
    strip bitcoind



FROM registry.suse.com/bci/bci-minimal:15.6
COPY --from=builder /bitcoin-0.2.8/bitcoind /usr/local/bin
COPY --from=builder /boost_1_57_0/stage/lib/libboost_system.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_filesystem.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_program_options.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_thread.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_chrono.so.1.57.0 /usr/lib64/
COPY --from=builder /usr/local/lib/libwx_baseu-2.9.so.5 /usr/lib64/
COPY --from=builder /usr/lib64/libgthread-2.0.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libglib-2.0.so.0 /usr/lib64/


COPY entrypoint.sh /entrypoint.sh
COPY bitcoin.conf /root/.bitcoin/bitcoin.conf
RUN chmod +x /entrypoint.sh
EXPOSE 8332 8333 15332 15333
ENTRYPOINT ["/entrypoint.sh"]

