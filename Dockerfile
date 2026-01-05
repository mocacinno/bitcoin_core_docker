FROM registry.suse.com/bci/bci-base:15.7 AS builder
RUN zypper ref -s && zypper --non-interactive install git wget libevent-devel awk libdb-4_8-devel sqlite3-devel libleveldb1 clang7 gcc gcc-c++ unzip libopenssl-devel && zypper --non-interactive install -t pattern devel_basis

#boost 1.66.0
WORKDIR /
RUN wget https://github.com/mocacinno/bitcoin_core_docker_prereqs/raw/refs/heads/gh-pages/boost_1_66_0.tar.gz -O boost_1_66_0.tar.gz 
RUN tar -xvf boost_1_66_0.tar.gz 
ENV BOOST_ROOT=/boost_1_66_0
WORKDIR /boost_1_66_0
RUN chmod +x bootstrap.sh 
RUN ./bootstrap.sh 
RUN ./b2  -j"$(($(nproc) + 1))" || ./b2 -j"$(($(nproc) + 1))" install || ./b2 -j"$(($(nproc) + 1))" headers 

#BerkeleyDB 4.8.30.NC
WORKDIR /berkeleydb
RUN wget https://raw.githubusercontent.com/bitcoin/bitcoin/refs/tags/v0.16.0/contrib/install_db4.sh
RUN chmod +x install_db4.sh
RUN ./install_db4.sh `pwd` 
ENV BDB_PREFIX='/berkeleydb/db4'

#bitcoin v0.16.0
WORKDIR /
RUN wget https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.16.0.zip && \
    unzip v0.16.0.zip
WORKDIR /bitcoin-0.16.0
RUN ./autogen.sh
RUN ./configure BDB_LIBS="-L${BDB_PREFIX}/lib -ldb_cxx-4.8" BDB_CFLAGS="-I${BDB_PREFIX}/include" --enable-util-cli --enable-util-tx --enable-util-wallet --enable-util-util CXX="g++ -std=c++98"
RUN make -j "$(($(nproc) + 1))"
WORKDIR /bitcoin-0.16.0/src
RUN strip bitcoind && strip bitcoin-cli && strip bitcoin-tx


FROM registry.suse.com/bci/bci-minimal:15.7
COPY --from=builder /bitcoin-0.16.0/src/bitcoin-cli /usr/local/bin
COPY --from=builder /bitcoin-0.16.0/src/bitcoin-tx /usr/local/bin
COPY --from=builder /bitcoin-0.16.0/src/bitcoind /usr/local/bin
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
COPY --from=builder /usr/lib64/libjitterentropy.so.3 /usr/lib64/

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 8332 8333 18332 18333
RUN echo 'bitcoinuser:x:10001:10001:Bitcoin User:/home/bitcoinuser:/bin/sh' >> /etc/passwd \
 && echo 'bitcoinuser:x:10001:' >> /etc/group \
 && mkdir -p /home/bitcoinuser \
 && chown -R 10001:10001 /home/bitcoinuser
USER bitcoinuser
LABEL org.opencontainers.image.revision="manual-trigger-20260105"
LABEL waitforfinish="true"
ENTRYPOINT ["/entrypoint.sh"]
