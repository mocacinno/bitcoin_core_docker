FROM registry.suse.com/bci/bci-base:15.6 AS builder

RUN zypper addrepo https://download.opensuse.org/repositories/devel:gcc/SLE-15/devel:gcc.repo
RUN zypper addrepo https://download.opensuse.org/repositories/home:MaxxedSUSE:Compiler-Tools-15.6/15.6/home:MaxxedSUSE:Compiler-Tools-15.6.repo
RUN zypper addrepo https://download.opensuse.org/repositories/devel:libraries:c_c++/SLE_12_SP5/devel:libraries:c_c++.repo
RUN zypper --gpg-auto-import-keys ref -s #gcc48
RUN zypper --non-interactive install gcc48 gcc48-c++ make automake makeinfo git gawk wget libicu-devel mlocate vim unzip cmake xz meson patch #gcc48
ENV CC=gcc-4.8
ENV CXX=g++-4.8
RUN ln -s /usr/bin/gcc-4.8 /usr/bin/gcc
RUN ln -s /usr/bin/g++-4.8 /usr/bin/g++

RUN wget https://sourceforge.net/projects/boost/files/boost/1.57.0/boost_1_57_0.tar.gz/download -O boost_1_57_0.tar.gz #boost1.57.0
RUN tar -xvf boost_1_57_0.tar.gz #boost1.57.0
ENV BOOST_ROOT=/boost_1_57_0
WORKDIR /boost_1_57_0
RUN chmod +x bootstrap.sh #boost1.57.0
RUN ./bootstrap.sh #boost1.57.0
RUN ./b2  -j"$(($(nproc) + 1))" || ./b2 -j"$(($(nproc) + 1))" install || ./b2 -j"$(($(nproc) + 1))" headers #boost1.57.0
RUN ln -s /boost_1_57_0/stage/lib/* /usr/lib64

WORKDIR /
RUN wget http://miniupnp.free.fr/files/download.php?file=miniupnpc-1.5.tar.gz -O miniupnpc-1.5.tar.gz
RUN tar -xvf miniupnpc-1.5.tar.gz
WORKDIR /miniupnpc-1.5
RUN make -j"$(($(nproc) + 1))" && make install
RUN ln -s /usr/lib/libminiupnpc.so.5 /usr/lib64
RUN ln -s /usr/lib/libminiupnpc.so /usr/lib64
RUN ln -s /usr/lib/libminiupnpc.a /usr/lib64

WORKDIR /
RUN wget http://download.oracle.com/berkeley-db/db-4.7.25.NC.tar.gz
RUN tar -xvf db-4.7.25.NC.tar.gz
WORKDIR /db-4.7.25.NC/build_unix
RUN ../dist/configure --enable-cxx
RUN make -j"$(($(nproc) + 1))" && make install
RUN ln -s /usr/local/BerkeleyDB.4.7/lib/* /usr/lib64/

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
RUN ln -s /usr/local/ssl/lib/lib* /usr/lib64/

WORKDIR /
RUN wget https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.3.8.zip
RUN unzip v0.3.8.zip
WORKDIR /bitcoin-0.3.8
#run g++ -v -c util.cpp
RUN make -j"$(($(nproc) + 1))" -f makefile.unix bitcoind CFLAGS="-I/openssl-0.9.8g/include -I/openssl-0.9.8g/include/openssl -I/db-4.7.25.NC/build_unix" LDFLAGS="-L/openssl-0.9.8g/lib -static"

WORKDIR /bitcoin-0.3.8
RUN strip bitcoind

FROM registry.suse.com/bci/bci-minimal:15.6
COPY --from=builder /bitcoin-0.3.8/bitcoind /usr/local/bin
COPY --from=builder /boost_1_57_0/stage/lib/libboost_system.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_filesystem.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_program_options.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_thread.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_chrono.so.1.57.0 /usr/lib64/
COPY --from=builder /glib-2.78.3/_build/gthread/libgthread-2.0.so.0 /usr/lib64/
COPY --from=builder /usr/local/lib64/libz.so /usr/lib64/
COPY --from=builder /db-4.7.25.NC/build_unix/.libs/libdb_cxx-4.7.so /usr/lib64/
COPY --from=builder /openssl-0.9.8g/libssl.so.0.9.8 /usr/lib64/
COPY --from=builder /usr/lib64/libglib-2.0.so.0 /usr/lib64/

COPY entrypoint.sh /entrypoint.sh
COPY bitcoin.conf /root/.bitcoin/bitcoin.conf
RUN chmod +x /entrypoint.sh
EXPOSE 8332 8333 15332 15333
ENTRYPOINT ["/entrypoint.sh"]
