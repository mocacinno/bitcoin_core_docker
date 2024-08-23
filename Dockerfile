FROM registry.suse.com/bci/bci-base:15.6 AS builder

COPY start.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/start.sh #proxy_0
RUN /usr/local/bin/start.sh #proxy_0
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

RUN chmod +x bootstrap.sh && ./bootstrap.sh && ./b2 || ./b2 headers #boost1.66.0
RUN git clone https://github.com/bitcoin/bitcoin.git /bitcoin #bitcoin_git
WORKDIR /bitcoin
RUN git fetch --all --tags
RUN git checkout tags/v22.1 -b v22.1 #v22.1
RUN ./contrib/install_db4.sh `pwd` #v22.1

ENV BDB_PREFIX='/bitcoin/db4'
RUN ./autogen.sh #v22.1


RUN ./configure BDB_LIBS="-L${BDB_PREFIX}/lib -ldb_cxx-4.8" BDB_CFLAGS="-I${BDB_PREFIX}/include"  --enable-util-cli --enable-util-tx --enable-util-wallet --enable-util-util #v22.1
#RUN./configure BDB_LIBS="-L${BDB_PREFIX}/lib -ldb_cxx-4.8" BDB_CFLAGS="-I${BDB_PREFIX}/include" --enable-util-cli --enable-util-tx --enable-util-wallet --enable-util-util LDFLAGS="-L/boost_1_66_0/stage/lib" LIBS="-lboost_system -lboost_filesystem" #v22.1
RUN make -j "$(($(nproc) + 1))" #v22.1
WORKDIR /bitcoin/src #bitcoin
RUN strip bitcoin-util && strip bitcoind && strip bitcoin-cli && strip bitcoin-tx
FROM registry.suse.com/bci/bci-minimal:15.6
COPY --from=builder /bitcoin/src/bitcoin-util /usr/local/bin
COPY --from=builder /bitcoin/src/bitcoin-cli /usr/local/bin
COPY --from=builder /bitcoin/src/bitcoin-tx /usr/local/bin
COPY --from=builder /bitcoin/src/bitcoind /usr/local/bin
COPY --from=builder /usr/lib64/libevent_pthreads-2.1.so.7 /usr/lib64/
COPY --from=builder /usr/lib64/libevent-2.1.so.7 /usr/lib64/
COPY --from=builder /usr/lib64/libdb_cxx-4.8.so /usr/lib64/
COPY --from=builder /usr/lib64/libsqlite3.so.0 /usr/lib64/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 8332 8333 18332 18333
ENTRYPOINT ["/entrypoint.sh"]