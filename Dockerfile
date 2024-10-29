FROM registry.suse.com/bci/bci-base:15.6 AS builder
RUN zypper ref -s && zypper --non-interactive install git wget libevent-devel awk libdb-4_8-devel sqlite3-devel libleveldb1 clang7 gcc-c++ libopenssl-devel unzip && zypper --non-interactive install -t pattern devel_basis

#boost 1.63.0
RUN wget https://archives.boost.io/release/1.63.0/source/boost_1_63_0.tar.gz 
RUN tar -xvf boost_1_63_0.tar.gz 
ENV BOOST_ROOT=/boost_1_63_0
WORKDIR /boost_1_63_0
RUN chmod +x bootstrap.sh 
RUN ./bootstrap.sh 
RUN ./b2  -j"$(($(nproc) + 1))" || ./b2 -j"$(($(nproc) + 1))" install || ./b2 -j"$(($(nproc) + 1))" headers

#bitcoin v0.14.1
WORKDIR /
RUN wget https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.14.1.zip && \
    unzip v0.14.1.zip
WORKDIR /bitcoin-0.14.1
RUN ./autogen.sh
RUN ldconfig
RUN ln -s /boost_1_63_0/stage/lib/libboost_system.so.1.63.0 /usr/lib64
RUN ./configure  --enable-util-cli --enable-util-tx --enable-util-wallet --enable-util-util CXX="g++ -std=c++98"
RUN make -j "$(($(nproc) + 1))" 
WORKDIR /bitcoin-0.14.1/src
RUN strip bitcoind && strip bitcoin-cli && strip bitcoin-tx


FROM registry.suse.com/bci/bci-minimal:15.6
COPY --from=builder /bitcoin-0.14.1/src/bitcoin-cli /usr/local/bin
COPY --from=builder /bitcoin-0.14.1/src/bitcoin-tx /usr/local/bin
COPY --from=builder /bitcoin-0.14.1/src/bitcoind /usr/local/bin
COPY --from=builder /usr/lib64/libevent_pthreads-2.1.so.7 /usr/lib64/
COPY --from=builder /usr/lib64/libevent-2.1.so.7 /usr/lib64/
COPY --from=builder /usr/lib64/libdb_cxx-4.8.so /usr/lib64/
COPY --from=builder /usr/lib64/libsqlite3.so.0 /usr/lib64/
COPY --from=builder /usr/lib64/libboost_system.so.1.63.0 /usr/lib64/
COPY --from=builder /boost_1_63_0/stage/lib/libboost_filesystem.so.1.63.0 /usr/lib64/
COPY --from=builder /boost_1_63_0/stage/lib/libboost_program_options.so.1.63.0 /usr/lib64/
COPY --from=builder /boost_1_63_0/stage/lib/libboost_thread.so.1.63.0 /usr/lib64/
COPY --from=builder /boost_1_63_0/stage/lib/libboost_chrono.so.1.63.0 /usr/lib64/
COPY --from=builder /usr/lib64/libssl.so.3 /usr/lib64/
COPY --from=builder /usr/lib64/libcrypto.so.3 /usr/lib64/
COPY --from=builder /usr/lib64/libjitterentropy.so.3 /usr/lib64/

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 8332 8333 18332 18333
ENTRYPOINT ["/entrypoint.sh"]
