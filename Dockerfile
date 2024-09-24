FROM registry.suse.com/bci/bci-base:15.6 AS builder
RUN zypper ref -s && zypper --non-interactive install git wget libevent-devel awk libdb-4_8-devel sqlite3-devel libleveldb1 clang7 gcc-c++ && zypper --non-interactive install -t pattern devel_basis #prereqs
RUN wget https://archives.boost.io/release/1.66.0/source/boost_1_66_0.tar.gz #boost1.66.0
RUN tar -xvf boost_1_66_0.tar.gz #boost1.66.0
ENV BOOST_ROOT=/boost_1_66_0
WORKDIR /boost_1_66_0

RUN zypper addrepo https://download.opensuse.org/repositories/devel:gcc/SLE-15/devel:gcc.repo
RUN zypper --gpg-auto-import-keys ref -s #gcc10
RUN zypper --non-interactive install gcc10 gcc10-c++ #gcc10
ENV CC=gcc-10
ENV CXX=g++-10

RUN chmod +x bootstrap.sh #boost1.66.0
RUN ./bootstrap.sh #boost1.66.0
RUN ./b2  -j"$(($(nproc) + 1))" || ./b2 -j"$(($(nproc) + 1))" install || ./b2 -j"$(($(nproc) + 1))" headers #boost1.66.0
RUN git clone https://github.com/bitcoin/bitcoin.git /bitcoin #bitcoin_git
WORKDIR /bitcoin
RUN git fetch --all --tags
RUN git checkout tags/v0.18.1 -b v0.18.1 #v0.18.1
RUN ./contrib/install_db4.sh `pwd` #v0.18.1
RUN zypper ref -s && zypper --non-interactive install libopenssl-devel
ENV BDB_PREFIX='/bitcoin/db4'
RUN ./autogen.sh #v0.18.1


RUN ./configure BDB_LIBS="-L${BDB_PREFIX}/lib -ldb_cxx-4.8" BDB_CFLAGS="-I${BDB_PREFIX}/include"  --enable-util-cli --enable-util-tx --enable-util-wallet --enable-util-util #v0.18.1
RUN make -j "$(($(nproc) + 1))" #v0.18.1
WORKDIR /bitcoin/src
RUN strip bitcoind && strip bitcoin-cli && strip bitcoin-tx
FROM registry.suse.com/bci/bci-minimal:15.6
COPY --from=builder /bitcoin/src/bitcoin-cli /usr/local/bin
COPY --from=builder /bitcoin/src/bitcoin-tx /usr/local/bin
COPY --from=builder /bitcoin/src/bitcoind /usr/local/bin
COPY --from=builder /usr/lib64/libevent_pthreads-2.1.so.7 /usr/lib64/
COPY --from=builder /usr/lib64/libevent-2.1.so.7 /usr/lib64/
COPY --from=builder /usr/lib64/libdb_cxx-4.8.so /usr/lib64/
COPY --from=builder /usr/lib64/libsqlite3.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libboost_system.so.1.66.0 /usr/lib64/
COPY --from=builder /boost_1_66_0/stage/lib/libboost_filesystem.so.1.66.0 /usr/lib64/
COPY --from=builder /boost_1_66_0/stage/lib/libboost_program_options.so.1.66.0 /usr/lib64/
COPY --from=builder /boost_1_66_0/stage/lib/libboost_thread.so.1.66.0 /usr/lib64/
COPY --from=builder /boost_1_66_0/stage/lib/libboost_chrono.so.1.66.0 /usr/lib64/
COPY --from=builder /usr/lib64/libssl.so.3 /usr/lib64/
COPY --from=builder /usr/lib64/libcrypto.so.3 /usr/lib64/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 8332 8333 18332 18333
ENTRYPOINT ["/entrypoint.sh"]
