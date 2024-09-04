FROM registry.suse.com/bci/bci-base:15.6 AS builder

#COPY start.sh /usr/local/bin/
#RUN chmod +x /usr/local/bin/start.sh
#RUN /usr/local/bin/start.sh
RUN zypper ref -s && zypper --non-interactive install git wget libevent-devel awk libdb-4_8-devel sqlite3-devel libleveldb1 clang7 && zypper --non-interactive install -t pattern devel_basis
RUN wget https://archives.boost.io/release/1.86.0/source/boost_1_86_0.tar.gz
RUN tar -xvf boost_1_86_0.tar.gz
ENV BOOST_ROOT=/boost_1_86_0
WORKDIR /boost_1_86_0

RUN zypper addrepo https://download.opensuse.org/repositories/devel:gcc/SLE-15/devel:gcc.repo
RUN zypper --gpg-auto-import-keys ref -s
RUN zypper --non-interactive install gcc10 gcc10-c++
ENV CC=gcc-10
ENV CXX=g++-10

RUN chmod +x bootstrap.sh && ./bootstrap.sh && ./b2 || ./b2 headers #boost1.86.0
RUN git clone https://github.com/bitcoin/bitcoin.git /bitcoin
WORKDIR /bitcoin
RUN git fetch --all --tags
RUN git checkout tags/v23.2 -b v23.2
RUN ./contrib/install_db4.sh `pwd`

ENV BDB_PREFIX='/bitcoin/db4'
RUN ./autogen.sh


RUN ./configure BDB_LIBS="-L${BDB_PREFIX}/lib -ldb_cxx-4.8" BDB_CFLAGS="-I${BDB_PREFIX}/include"  --enable-util-cli --enable-util-tx --enable-util-wallet --enable-util-util
RUN make -j "$(($(nproc) + 1))" #v23.2
WORKDIR /bitcoin/src
RUN strip bitcoin-util && strip bitcoind && strip bitcoin-cli && strip bitcoin-tx  #v23.2
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
