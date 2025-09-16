FROM registry.suse.com/bci/bci-base:15.7 AS builder

RUN zypper ref -s && zypper --non-interactive install git gcc14-c++ wget libevent-devel awk gcc-c++ libdb-4_8-devel sqlite3-devel unzip && zypper --non-interactive install -t pattern devel_basis

#boost 1.87.0
RUN wget https://archives.boost.io/release/1.87.0/source/boost_1_87_0.tar.gz
RUN tar -xvf boost_1_87_0.tar.gz
ENV BOOST_ROOT=/boost_1_87_0
WORKDIR /boost_1_87_0
RUN chmod +x bootstrap.sh 
RUN ./bootstrap.sh 
RUN ./b2  -j"$(($(nproc) + 1))" || ./b2 -j"$(($(nproc) + 1))" install || ./b2 -j"$(($(nproc) + 1))" headers 

#BerkeleyDB 4.8.30.NC
WORKDIR /berkeleydb
RUN wget https://raw.githubusercontent.com/bitcoin/bitcoin/refs/tags/v0.16.0/contrib/install_db4.sh
RUN chmod +x install_db4.sh
RUN ./install_db4.sh `pwd` 
ENV BDB_PREFIX='/berkeleydb/db4'

#bitcoin v25.0
WORKDIR /
RUN wget https://github.com/bitcoin/bitcoin/archive/refs/tags/v25.0.zip && \
    unzip v25.0.zip
WORKDIR /bitcoin-25.0
RUN ./autogen.sh 
RUN BDB_LIBS="-L${BDB_PREFIX}/lib -ldb_cxx-4.8" BDB_CFLAGS="-I${BDB_PREFIX}/include" ./configure --with-gui=no --enable-wallet --with-sqlite=yes --with-utils --with-daemon CXX=g++-14
RUN make -j "$(($(nproc) + 1))" 
WORKDIR /bitcoin-25.0/src
RUN strip bitcoin-util && strip bitcoind && strip bitcoin-cli && strip bitcoin-tx  

FROM registry.suse.com/bci/bci-minimal:15.7
COPY --from=builder /bitcoin-25.0/src/bitcoin-util /usr/local/bin
COPY --from=builder /bitcoin-25.0/src/bitcoin-cli /usr/local/bin
COPY --from=builder /bitcoin-25.0/src/bitcoin-tx /usr/local/bin
COPY --from=builder /bitcoin-25.0/src/bitcoind /usr/local/bin
COPY --from=builder /usr/lib64/libevent_pthreads-2.1.so.7 /usr/lib64/
COPY --from=builder /usr/lib64/libevent-2.1.so.7 /usr/lib64/
COPY --from=builder /usr/lib64/libdb_cxx-4.8.so /usr/lib64/
COPY --from=builder /usr/lib64/libsqlite3.so.0 /usr/lib64/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 8332 8333 18332 18333
RUN echo 'bitcoinuser:x:10001:10001:Bitcoin User:/home/bitcoinuser:/bin/sh' >> /etc/passwd \
 && echo 'bitcoinuser:x:10001:' >> /etc/group \
 && mkdir -p /home/bitcoinuser \
 && chown -R 10001:10001 /home/bitcoinuser
USER bitcoinuser
LABEL org.opencontainers.image.revision="manual-trigger-20250915"
LABEL waitforfinish="true"
ENTRYPOINT ["/entrypoint.sh"]
