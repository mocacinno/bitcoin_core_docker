FROM registry.suse.com/bci/bci-base:15.6 AS builder

RUN zypper addrepo https://download.opensuse.org/repositories/devel:gcc/SLE-15/devel:gcc.repo
RUN zypper addrepo https://download.opensuse.org/repositories/home:MaxxedSUSE:Compiler-Tools-15.6/15.6/home:MaxxedSUSE:Compiler-Tools-15.6.repo
RUN zypper addrepo https://download.opensuse.org/repositories/devel:libraries:c_c++/SLE_12_SP5/devel:libraries:c_c++.repo
RUN zypper --gpg-auto-import-keys ref -s #gcc57
#RUN zypper --non-interactive install cmake xz meson gcc6 gcc6-c++ make automake makeinfo git gawk libdb-4_8-devel libopenssl-1_0_0-devel wget xmllint libicu-devel libminiupnpc-devel libupnp-devel patch libopenssl1_0_0  #gcc6
RUN zypper --non-interactive install  mlocate cmake xz meson gcc6 gcc6-c++ make automake makeinfo git gawk wget libicu-devel patch vim #gcc6
ENV CC=gcc-6
ENV CXX=g++-6
RUN ln -s /usr/bin/gcc-6 /usr/bin/gcc
RUN ln -s /usr/bin/g++-6 /usr/bin/g++



RUN wget https://sourceforge.net/projects/boost/files/boost/1.57.0/boost_1_57_0.tar.gz/download -O boost_1_57_0.tar.gz #boost1.57.0
RUN tar -xvf boost_1_57_0.tar.gz #boost1.57.0
ENV BOOST_ROOT=/boost_1_57_0
WORKDIR /boost_1_57_0
RUN chmod +x bootstrap.sh #boost1.57.0
RUN ./bootstrap.sh #boost1.57.0
RUN ./b2  -j"$(($(nproc) + 1))" || ./b2 -j"$(($(nproc) + 1))" install || ./b2 -j"$(($(nproc) + 1))" headers #boost1.57.0

WORKDIR /
RUN wget http://miniupnp.free.fr/files/download.php?file=miniupnpc-1.6.tar.gz -O miniupnpc-1.6.tar.gz
RUN tar -xvf miniupnpc-1.6.tar.gz
WORKDIR /miniupnpc-1.6
RUN make -j"$(($(nproc) + 1))" && make install
RUN ln -s /usr/lib/libminiupnpc.so.8 /usr/lib64
RUN ln -s /usr/lib/libminiupnpc.so /usr/lib64


WORKDIR /
RUN wget https://download.gnome.org/sources/glib/2.78/glib-2.78.3.tar.xz
RUN xz -d glib-2.78.3.tar.xz
RUN tar -xvf glib-2.78.3.tar
WORKDIR /glib-2.78.3/subprojects
RUN wget https://github.com/PCRE2Project/pcre2/archive/refs/tags/pcre2-10.37.tar.gz -O pcre2-10.37.tar.gz
RUN tar -xvf pcre2-10.37.tar.gz
RUN mv pcre2-pcre2-10.37/ pcre2
WORKDIR /glib-2.78.3
RUN meson setup _build --wrap-mode=forcefallback -Dc_args="-Wno-error=unused-result" -Dcpp_args="-Wno-error=unused-result" -Dwarning_level=0
RUN meson compile -C _build                 # build GLib
RUN meson install -C _build                 # install GLib

WORKDIR /
RUN wget http://download.oracle.com/berkeley-db/db-4.8.30.NC.tar.gz
RUN tar -xvf db-4.8.30.NC.tar.gz
WORKDIR /db-4.8.30.NC/build_unix
RUN ../dist/configure --enable-cxx
RUN make -j"$(($(nproc) + 1))" && make install

WORKDIR /
RUN wget https://www.openssl.org/source/openssl-0.9.8g.tar.gz
RUN tar -xvf openssl-0.9.8g.tar.gz
WORKDIR /openssl-0.9.8g
RUN ./config
RUN make 
RUN make install_sw
RUN ./config shared --prefix=/usr/local/ssl
RUN make  
RUN make install_sw

RUN git clone https://github.com/bitcoin/bitcoin.git /bitcoin #bitcoin_git

WORKDIR /bitcoin
RUN git fetch --all --tags
RUN git checkout tags/v0.4.0 -b v0.4.0 #v0.4.0
WORKDIR /bitcoin/src
COPY patch_mocacinno_net /bitcoin/src/patch_mocacinno_net
COPY patch_mocacinno_makefile /bitcoin/src/patch_mocacinno_makefile
RUN patch net.cpp < patch_mocacinno_net
RUN patch makefile.unix < patch_mocacinno_makefile
RUN ln -s /usr/local/BerkeleyDB.4.8/lib/libdb_cxx.so /usr/lib64/libdb_cxx.so
RUN ln -s /usr/local/ssl/lib/libssl.so /usr/lib64/libssl.so
RUN ln -s /usr/local/ssl/lib/libcrypto.so /usr/lib64/libcrypto.so
RUN ln -s /usr/local/ssl/lib/libcrypto.a /usr/lib64/
ENV LD_LIBRARY_PATH=/usr/local/BerkeleyDB.4.8/lib:/usr/local/ssl/lib:/usr/local/lib:
ENV LD_RUN_PATH=/usr/local/BerkeleyDB.4.8/lib:/usr/local/ssl/lib
RUN make -j"$(($(nproc) + 1))" -f makefile.unix bitcoind LDFLAGS="-L/usr/local/BerkeleyDB.4.8/lib -L/usr/local/ssl/lib" CXXFLAGS="-I/usr/local/ssl/include -I/usr/local/BerkeleyDB.4.8/include/"


WORKDIR /bitcoin/src
RUN strip bitcoind 

FROM registry.suse.com/bci/bci-minimal:15.6
COPY --from=builder /bitcoin/src/bitcoind /usr/local/bin

COPY --from=builder /boost_1_57_0/stage/lib/libboost_system.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_filesystem.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_program_options.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_thread.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_chrono.so.1.57.0 /usr/lib64/
COPY --from=builder /glib-2.78.3/_build/gthread/libgthread-2.0.so.0 /usr/lib64/
COPY --from=builder /usr/local/lib64/libz.so /usr/lib64/
COPY --from=builder /db-4.8.30.NC/build_unix/.libs/libdb_cxx-4.8.so /usr/lib64/
COPY --from=builder /openssl-0.9.8g/libssl.so.0.9.8 /usr/lib64/
COPY --from=builder /usr/lib64/libglib-2.0.so.0 /usr/lib64/

COPY entrypoint.sh /entrypoint.sh
COPY bitcoin.conf /root/.bitcoin/bitcoin.conf
RUN chmod +x /entrypoint.sh
EXPOSE 8572 8573 18572 18573
ENTRYPOINT ["/entrypoint.sh"]
