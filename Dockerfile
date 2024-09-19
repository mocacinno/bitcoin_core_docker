FROM registry.suse.com/bci/bci-base:15.6 AS builder

RUN zypper addrepo https://download.opensuse.org/repositories/devel:gcc/SLE-15/devel:gcc.repo && \
    zypper addrepo https://download.opensuse.org/repositories/home:MaxxedSUSE:Compiler-Tools-15.6/15.6/home:MaxxedSUSE:Compiler-Tools-15.6.repo && \
    zypper addrepo https://download.opensuse.org/repositories/devel:libraries:c_c++/SLE_12_SP5/devel:libraries:c_c++.repo && \
    zypper addrepo https://download.opensuse.org/repositories/home:steffens:branches:Application:Geo:qgis/SLE_11_SP4/home:steffens:branches:Application:Geo:qgis.repo && \
    zypper --gpg-auto-import-keys ref -s && \
    zypper --non-interactive install pango-devel pango-tools && \
    zypper --non-interactive install gcc48 gcc48-c++ make automake makeinfo git gawk wget libicu-devel mlocate vim unzip cmake xz meson patch
ENV CC=gcc-4.8
ENV CXX=g++-4.8
ENV PERL5LIB=.
RUN ln -s /usr/bin/gcc-4.8 /usr/bin/gcc && \
    ln -s /usr/bin/g++-4.8 /usr/bin/g++

# WORKDIR /
# RUN wget https://download.gnome.org/sources/glib/2.78/glib-2.78.3.tar.xz
# RUN xz -d glib-2.78.3.tar.xz
# RUN tar -xvf glib-2.78.3.tar
# WORKDIR /glib-2.78.3/subprojects
# RUN wget https://github.com/PCRE2Project/pcre2/archive/refs/tags/pcre2-10.37.tar.gz -O pcre2-10.37.tar.gz
# RUN tar -xvf pcre2-10.37.tar.gz
# RUN mv pcre2-pcre2-10.37/ pcre2
# WORKDIR /glib-2.78.3
# RUN meson setup _build --wrap-mode=forcefallback -Dc_args="-Wno-error=unused-result" -Dcpp_args="-Wno-error=unused-result" -Dwarning_level=0
# RUN meson compile -C _build                 # build GLib
# RUN meson install -C _build                 # install GLib

#success, openssl v0.9.8k (prereq of core)
WORKDIR /
RUN wget https://www.openssl.org/source/openssl-0.9.8k.tar.gz && \
    tar -xvf openssl-0.9.8k.tar.gz
WORKDIR /openssl-0.9.8k
RUN ./config && \
    make && \
    make install_sw && \
    ln -s /usr/local/ssl/lib/lib* /usr/lib64/

#success, berkelydb 4.2.25.NC (prereq of core)
WORKDIR /
RUN wget http://download.oracle.com/berkeley-db/db-4.7.25.NC.tar.gz && \
    tar -xvf db-4.7.25.NC.tar.gz
WORKDIR /db-4.7.25.NC/build_unix
RUN ../dist/configure --enable-cxx && \
    make -j"$(($(nproc) + 1))" && make install && \
    ln -s /usr/local/BerkeleyDB.4.7/lib/* /usr/lib64/

#success, boost 1.57.0 (prereq of core)
WORKDIR /
RUN wget https://sourceforge.net/projects/boost/files/boost/1.57.0/boost_1_57_0.tar.gz/download -O boost_1_57_0.tar.gz && \
    tar -xvf boost_1_57_0.tar.gz
ENV BOOST_ROOT=/boost_1_57_0
WORKDIR /boost_1_57_0
RUN chmod +x bootstrap.sh #boost1.57.0 && \
    ./bootstrap.sh #boost1.57.0 && \
    ./b2  -j"$(($(nproc) + 1))" || ./b2 -j"$(($(nproc) + 1))" install || ./b2 -j"$(($(nproc) + 1))" headers #boost1.57.0 && \
    ln -s /boost_1_57_0/stage/lib/* /usr/lib64

#success, libtool-1.4.1
WORKDIR /
RUN wget http://ftp.gnu.org/gnu/libtool/libtool-1.4.1.tar.gz && \
    tar -xvf libtool-1.4.1.tar.gz
WORKDIR /libtool-1.4.1
RUN ./configure && \
    make -j"$(($(nproc) + 1))" && \
    make install

#success, gtk-doc 1.2
WORKDIR /
RUN zypper --non-interactive  in jade docbook_3 docbook-xsl-stylesheets && \
    wget https://download.gnome.org/sources/gtk-doc/1.2/gtk-doc-1.2.tar.gz && \
    tar -xvf gtk-doc-1.2.tar.gz
WORKDIR /gtk-doc-1.2
RUN ./configure && \
    make -j"$(($(nproc) + 1))" || true && \
    make install

#success, automake 1.7.9
WORKDIR /
RUN wget http://ftp.gnu.org/gnu/automake/automake-1.7.9.tar.gz && \
    tar -xvf automake-1.7.9.tar.gz
WORKDIR /automake-1.7.9
RUN ./configure && \
    make -j"$(($(nproc) + 1))" && \
    make install

#upgraded autoconf because other sources failed to build with 2.54 (upgrade to 2.57)
#WORKDIR /
#RUN wget http://ftp.gnu.org/gnu/autoconf/autoconf-2.54.tar.gz
#RUN tar -xvf autoconf-2.54.tar.gz
#WORKDIR /autoconf-2.54
#RUN ./configure M4=/usr/bin/m4
#RUN make -j"$(($(nproc) + 1))"
#RUN make install

#success, autoconf 2.57
WORKDIR /
RUN wget http://ftp.gnu.org/gnu/autoconf/autoconf-2.57.tar.gz && \
    tar -xvf autoconf-2.57.tar.gz
WORKDIR /autoconf-2.57
RUN ./configure M4=/usr/bin/m4 && \
    make -j"$(($(nproc) + 1))" && \
    make install

#success atk 1.0.2
WORKDIR /
RUN wget https://download.gnome.org/sources/atk/1.0/atk-1.0.2.tar.gz && \
    tar -xvf atk-1.0.2.tar.gz
WORKDIR /atk-1.0.2
RUN sed -i 's/\bindex\b/index_counter/g' ./atk/atkutil.c && \
    ./configure && \
    make -j"$(($(nproc) + 1))" && \
    make install

#success libXft 2.1.14
WORKDIR /
RUN wget https://www.x.org/releases/individual/lib/libXft-2.1.14.tar.gz && \
    tar -xzf libXft-2.1.14.tar.gz
WORKDIR /libXft-2.1.14
RUN ./configure && \
    make && \
    make install

#success libXrender 0.9.0.2
WORKDIR /
RUN wget https://www.x.org/releases/individual/lib/libXrender-0.9.0.2.tar.gz && \
    tar -xzf libXrender-0.9.0.2.tar.gz
WORKDIR /libXrender-0.9.0.2
RUN ./configure && \
    make && \
    make install

#sucess libXext 1.2.0
WORKDIR / 
RUN wget https://www.x.org/releases/individual/lib/libXext-1.2.0.tar.gz && \
    tar -xzf libXext-1.2.0.tar.gz
WORKDIR /libXext-1.2.0
RUN rm -rf config.cache config.log || true && \
    wget https://gitlab.x2go.org/x2go/vcxsrv/-/raw/212ca5c6023b6b7455ad64b2c29aeff82f301a03/X11/extensions/dpmsstr.h?inline=false -O /usr/include/X11/extensions/dpmsstr.h && \
    wget https://gitlab.x2go.org/x2go/vcxsrv/-/raw/212ca5c6023b6b7455ad64b2c29aeff82f301a03/X11/extensions/mitmiscstr.h?inline=false -O /usr/include/X11/extensions/mitmiscstr.h && \
    ./configure && \
    make && \
    make install



#libX11 seems like a prereq that's not needed...
#WORKDIR /
#RUN wget https://www.x.org/releases/individual/lib/libX11-1.1.2.tar.gz
#RUN tar -xvf libX11-1.1.2.tar.gz
#WORKDIR /libX11-1.1.2
#RUN sed -i '33i m4_pattern_allow([XTRANS_CONNECTION_FLAGS])' configure.ac
#RUN aclocal
#RUN autoconf
#RUN autoheader
#RUN libtoolize --force --copy
#RUN automake -if || true
#RUN sed -i 's/\$ac_compiler -V/\$ac_compiler --version/' configure
#RUN ./configure


#success, util-macros 1.3.0
WORKDIR /
RUN wget https://gitlab.freedesktop.org/xorg/util/macros/-/archive/util-macros-1.3.0/macros-util-macros-1.3.0.tar.gz && \
    tar -xvf macros-util-macros-1.3.0.tar.gz
WORKDIR /macros-util-macros-1.3.0
RUN sed -i '24i m4_pattern_allow([AS_HELP_STRING])' configure.ac  && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install


#success libXtrans 1.0.2
WORKDIR / 
RUN wget https://gitlab.freedesktop.org/xorg/lib/libxtrans/-/archive/xtrans-1.0.2/libxtrans-xtrans-1.0.2.tar.gz && \
    tar -xvf libxtrans-xtrans-1.0.2.tar.gz
WORKDIR /libxtrans-xtrans-1.0.2
RUN sed -i '24i m4_pattern_allow([AS_HELP_STRING])' configure.ac && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install

#success, libICE 1.0.2
WORKDIR / 
RUN wget https://gitlab.freedesktop.org/xorg/lib/libice/-/archive/libICE-1.0.2/libice-libICE-1.0.2.tar.gz && \
    tar -xvf libice-libICE-1.0.2.tar.gz
WORKDIR /libice-libICE-1.0.2
RUN sed -i '24i m4_pattern_allow([AS_HELP_STRING])' configure.ac && \
    ln -s /usr/share/aclocal/*.m4 /usr/local/share/aclocal && \
    zypper --non-interactive install autoconf automake libtool pkg-config libxkbcommon-x11-devel libtiff-devel libjpeg62-devel && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install

#success libSM 1.1.1
WORKDIR /
RUN wget https://gitlab.freedesktop.org/xorg/lib/libsm/-/archive/libSM-1.0.2/libsm-libSM-1.0.2.tar.gz && \
    tar -xvf libsm-libSM-1.0.2.tar.gz
WORKDIR /libsm-libSM-1.0.2
RUN sed -i '24i m4_pattern_allow([AS_HELP_STRING])' configure.ac && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install

#todo libXt 1.0.2
WORKDIR / 
RUN wget https://www.x.org/releases/individual/lib/libXt-1.0.0.tar.gz && \
    tar -xvf libXt-1.0.0.tar.gz
WORKDIR /libXt-1.0.0
RUN sed -i '24i m4_pattern_allow([AS_HELP_STRING])' configure.ac 
#    sed -i '24i AC_DEFINE([unix], 1, [Define if running on Unix])' configure.ac && \
    #sed -i 's/ac_compiler_check/ECHO_OK/' configure.ac && \
    autoreconf -v --install


#todo GTK 2.4.14
WORKDIR /
RUN wget https://github.com/GNOME/gtk/archive/refs/tags/GTK_2_4_14.zip && \
    unzip GTK_2_4_14.zip
WORKDIR /gtk-GTK_2_4_14
RUN mkdir build 
#RUN aclocal

RUN sed -i '24i m4_pattern_allow([AC_MSG_FAILURE])' configure.in && \
    sed -i '24i m4_pattern_allow([_PKG_TEXT])' configure.in && \
    sed -i '24i m4_pattern_allow([AS_VAR_COPY])' configure.in && \
    sed -i '24i m4_pattern_allow([AS_VAR_IF])' configure.in
#RUN sed -i '24i m4_pattern_allow([PKG_CHECK_MODULES])' configure.in
#RUN ./autogen.sh || true
#RUN autoreconf -i
#RUN aclocal -I /usr/share/aclocal
RUN aclocal && \
    autoconf && \
    autoheader && \
    libtoolize --force --copy && \
    ln -s /usr/local/share/gtk-doc/data/gtk-doc.make . && \
    automake --add-missing && \
    sed -i '8715,8722c\ echo "this shit is too old man"' configure && \
    sed -i 's/AS_VAR_COPY(\([^,]*\),\([^)]*\))/\1=\2/' configure && \
    sed -i 's/AS_VAR_IF(\([^,]*\), "", , )/if [ -z "\1" ]; then :; fi/' configure
#RUN ./configure --without-libtiff --without-libjpeg
#RUN zypper --non-interactive install autoconf-archive
#RUN sed -i '24i m4_pattern_allow([dnl])' configure.in
#RUN sed -i '24i m4_pattern_allow([AS_VAR_COPY])' configure.in
#RUN sed -i '24i m4_pattern_allow([AS_VAR_IF])' configure.in
#ENV ACLOCAL_FLAGS="-I /usr/local/share/aclocal-1.7"
#RUN aclocal $ACLOCAL_FLAGS || true
#RUN autoconf || true
#RUN cp /usr/share/aclocal-1.15/as.m4 /usr/share/aclocal
#ENV ACLOCAL_FLAGS="-I /usr/share/aclocal"
#RUN aclocal $ACLOCAL_FLAGS
#RUN autoconf
#RUN aclocal || true
#./autogen.sh
#automake-1.7 -v
#autoconf

#todo wxwidgets 2.9.0 (direct bitcoin core prereq)
WORKDIR /
RUN wget https://github.com/wxWidgets/wxWidgets/archive/refs/tags/v2.9.0.tar.gz && \
    tar -xvf v2.9.0.tar.gz


#todo bitcoin core v0.3.2
WORKDIR /
#if fails, first browse to https://sourceforge.net/p/bitcoin/code/107/tree/ and download snapshot
RUN wget https://github.com/mocacinno/bitcoin_core_history/archive/refs/heads/v0.3.2.zip && \
    unzip v0.3.2.zip
WORKDIR /v0.3.2
COPY mocacinno_patch_nowx.patch /mocacinno_patch_nowx.patch
RUN zypper --non-interactive install dos2unix && \
    find /v0.3.2/ -type f -exec dos2unix {} +
#RUN patch -p1 < ../mocacinno_patch_nowx.patch

#RUN  make -f makefile.unix bitcoind CFLAGS="-I/openssl-0.9.8k/include -I/db-4.7.25.NC/build_unix" LDFLAGS="-L/openssl-0.9.8k/lib -static"

#RUN strip bitcoind

#FROM registry.suse.com/bci/bci-minimal:15.6
#COPY --from=builder /bitcoin-code-r107-trunk/bitcoind /usr/local/bin
#COPY --from=builder /boost_1_57_0/stage/lib/libboost_system.so.1.57.0 /usr/lib64/
#COPY --from=builder /boost_1_57_0/stage/lib/libboost_filesystem.so.1.57.0 /usr/lib64/
#COPY --from=builder /boost_1_57_0/stage/lib/libboost_program_options.so.1.57.0 /usr/lib64/
#COPY --from=builder /boost_1_57_0/stage/lib/libboost_thread.so.1.57.0 /usr/lib64/
#COPY --from=builder /boost_1_57_0/stage/lib/libboost_chrono.so.1.57.0 /usr/lib64/
#COPY --from=builder /glib-2.78.3/_build/gthread/libgthread-2.0.so.0 /usr/lib64/
#COPY --from=builder /usr/local/lib64/libz.so /usr/lib64/
#COPY --from=builder /db-4.7.25.NC/build_unix/.libs/libdb_cxx-4.7.so /usr/lib64/
#COPY --from=builder /usr/lib64/libssl.so.1.1 /usr/lib64/
#COPY --from=builder /usr/lib64/libglib-2.0.so.0 /usr/lib64/

#COPY entrypoint.sh /entrypoint.sh
#COPY bitcoin.conf /root/.bitcoin/bitcoin.conf
#RUN chmod +x /entrypoint.sh
#EXPOSE 8332 8333 15332 15333
#ENTRYPOINT ["/entrypoint.sh"]

