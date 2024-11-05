FROM registry.suse.com/bci/bci-base:15.6 AS builder
RUN zypper addrepo https://download.opensuse.org/repositories/devel:gcc/SLE-15/devel:gcc.repo
RUN zypper --gpg-auto-import-keys ref -s
RUN zypper ref -s && zypper --non-interactive install git wget libevent-devel awk libdb-4_8-devel sqlite3-devel libleveldb1 clang7 gcc10 gcc10-c++ unzip && zypper --non-interactive install -t pattern devel_basis

#gcc 10
ENV CC=gcc-10
ENV CXX=g++-10

#boost 1.86.0
RUN wget https://archives.boost.io/release/1.86.0/source/boost_1_86_0.tar.gz
RUN tar -xvf boost_1_86_0.tar.gz
ENV BOOST_ROOT=/boost_1_86_0
WORKDIR /boost_1_86_0
RUN chmod +x bootstrap.sh 
RUN ./bootstrap.sh 
RUN ./b2  -j"$(($(nproc) + 1))" || ./b2 -j"$(($(nproc) + 1))" install || ./b2 -j"$(($(nproc) + 1))" headers 

#BerkeleyDB 4.8.30.NC
WORKDIR /berkeleydb
RUN wget https://raw.githubusercontent.com/bitcoin/bitcoin/refs/tags/v24.2/contrib/install_db4.sh
RUN chmod +x install_db4.sh
RUN ./install_db4.sh `pwd` 
ENV BDB_PREFIX='/berkeleydb/db4'

#bitcoin v23.0
WORKDIR /
RUN wget https://github.com/bitcoin/bitcoin/archive/refs/tags/v23.0.zip && \
    unzip v23.0.zip
WORKDIR /bitcoin-23.0
RUN ./autogen.sh
RUN ./configure BDB_LIBS="-L${BDB_PREFIX}/lib -ldb_cxx-4.8" BDB_CFLAGS="-I${BDB_PREFIX}/include"  --enable-util-cli --enable-util-tx --enable-util-wallet --enable-util-util
RUN make -j "$(($(nproc) + 1))" 
WORKDIR /bitcoin-23.0/src
RUN strip bitcoin-util && strip bitcoind && strip bitcoin-cli && strip bitcoin-tx  


FROM registry.suse.com/bci/bci-minimal:15.6
COPY --from=builder /bitcoin-23.0/src/bitcoin-util /usr/local/bin
COPY --from=builder /bitcoin-23.0/src/bitcoin-cli /usr/local/bin
COPY --from=builder /bitcoin-23.0/src/bitcoin-tx /usr/local/bin
COPY --from=builder /bitcoin-23.0/src/bitcoind /usr/local/bin
COPY --from=builder /usr/lib64/libevent_pthreads-2.1.so.7 /usr/lib64/
COPY --from=builder /usr/lib64/libevent-2.1.so.7 /usr/lib64/
COPY --from=builder /usr/lib64/libdb_cxx-4.8.so /usr/lib64/
COPY --from=builder /usr/lib64/libsqlite3.so.0 /usr/lib64/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 8332 8333 18332 18333
ENTRYPOINT ["/entrypoint.sh"]
