FROM registry.suse.com/bci/bci-base:15.7 AS builder

RUN zypper addrepo https://download.opensuse.org/repositories/devel:gcc/SLE-15/devel:gcc.repo && \
    zypper addrepo https://download.opensuse.org/repositories/home:MaxxedSUSE:Compiler-Tools-15.6/15.6/home:MaxxedSUSE:Compiler-Tools-15.6.repo && \
    zypper addrepo https://download.opensuse.org/repositories/devel:libraries:c_c++/15.7/devel:libraries:c_c++.repo && \
    zypper --gpg-auto-import-keys ref -s && \
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


#wxwidgets 2.9.0
WORKDIR /
RUN wget https://github.com/wxWidgets/wxWidgets/archive/refs/tags/v2.9.0.zip && \
    unzip v2.9.0.zip
WORKDIR /wxWidgets-2.9.0
 RUN ./autogen.sh && \
    CXXFLAGS="-fPIC -fpermissive" CFLAGS="-fPIC -fpermissive" ./configure --enable-unicode --enable-debug --prefix=/usr/local/wxwidgets  --with-gtk --enable-shared --enable-monolithic && \
    ln -s /usr/lib64/libjpeg.so.8 /usr/lib64/libjpeg8.so && \
    unlink /usr/lib64/libjpeg.so && \
    ln -s /usr/lib64/libjpeg.so.8.2.2 /usr/lib64/libjpeg.so && \
    CXXFLAGS="-fPIC -fpermissive" CFLAGS="-fPIC" make -j"$(($(nproc) + 1))" LDFLAGS="-lpangocairo-1.0 -lX11 -lcairo -ljpeg8" && \
    make install && \
    cp -R /wxWidgets-2.9.0/lib/* /usr/lib64/ && \
    ldconfig 

#xauth and fonts for gui
RUN zypper addrepo https://download.opensuse.org/repositories/home:plasmaregataos/15.6/home:plasmaregataos.repo && \
    zypper addrepo https://download.opensuse.org/repositories/X11:/XOrg/SLE_15_SP7/X11:XOrg.repo && \
    zypper --gpg-auto-import-keys ref -s && \
    zypper --non-interactive install xauth dejavu-fonts

#bitcoin core v0.2.1
WORKDIR /
RUN wget https://github.com/mocacinno/bitcoin_core_history/archive/refs/heads/v0.2.1.zip && \
    unzip v0.2.1.zip
WORKDIR /bitcoin_core_history-0.2.1
RUN mkdir -p obj/nogui && \
    dos2unix makefile.unix.wx2.9 && \
    cp makefile.unix.wx2.9 makefile.unix.orig && \
    sed -i '29s/-mt//g' makefile.unix.wx2.9 && \
    sed -i '/-Wl,-Bstatic/,/-Wl,-Bdynamic/ s/-l wx_gtk2u\$(D)-2.9//' makefile.unix.wx2.9 && \
    sed -i '/-l SM/ s/-l SM/-l SM -l wx_gtk2ud-2.9/' makefile.unix.wx2.9 && \
    CFLAGS="-fPIC -fpermissive" make -f makefile.unix.wx2.9 bitcoin CFLAGS="-I/usr/local/wxwidgets/include/wx-2.9 -I/usr/lib64/wx/include/gtk2-unicode-debug-2.9 -I/openssl-0.9.8k/include -I/usr/local/BerkeleyDB.4.7/include -fpermissive -I/wxWidgets-2.9.0/lib/wx/include/gtk2-unicode-debug-2.9 -I/wxWidgets-2.9.0/include -D_FILE_OFFSET_BITS=64 -D__WXDEBUG__ -DWXUSINGDLL -D__WXGTK__ -pthread" && \
    strip bitcoin
RUN ln -s /bitcoin_core_history-0.2.1/bitcoin /usr/local/bin


COPY entrypoint.sh /entrypoint.sh
COPY bitcoin.conf /root/.bitcoin/bitcoin.conf
RUN chmod +x /entrypoint.sh
EXPOSE 8332 8333 15332 15333
LABEL org.opencontainers.image.revision="manual-trigger-20250819"
#wait for finish
ENTRYPOINT ["/entrypoint.sh"]
