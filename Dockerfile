FROM registry.suse.com/bci/bci-base:15.6 AS builder
RUN zypper addrepo https://download.opensuse.org/repositories/home:MaxxedSUSE:Compiler-Tools-15.6/15.6/home:MaxxedSUSE:Compiler-Tools-15.6.repo
RUN zypper --gpg-auto-import-keys ref -s
RUN zypper ref -s && zypper --non-interactive install git wget libevent-devel awk libdb-4_8-devel sqlite3-devel libleveldb1 clang7 gcc-c++ unzip libopenssl-1_0_0-devel && zypper --non-interactive install -t pattern devel_basis

#boost 1.57.0
RUN wget https://sourceforge.net/projects/boost/files/boost/1.57.0/boost_1_57_0.tar.gz/download -O boost_1_57_0.tar.gz
RUN tar -xvf boost_1_57_0.tar.gz
ENV BOOST_ROOT=/boost_1_57_0
WORKDIR /boost_1_57_0
RUN chmod +x bootstrap.sh
RUN ./bootstrap.sh
RUN ./b2  -j"$(($(nproc) + 1))" || ./b2 -j"$(($(nproc) + 1))" install || ./b2 -j"$(($(nproc) + 1))" headers


#bitcoin v0.9.5
WORKDIR /
RUN wget https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.10.0.zip && \
    unzip v0.10.0.zip
WORKDIR /bitcoin-0.10.0
RUN ./autogen.sh
RUN ldconfig
RUN ./configure  --enable-util-cli --enable-util-tx --enable-util-wallet --enable-util-util CXX="g++ -std=c++98" #v0.10.0
RUN make -j "$(($(nproc) + 1))"
WORKDIR /bitcoin-0.10.0/src
RUN strip bitcoind && strip bitcoin-cli && strip bitcoin-tx

FROM registry.suse.com/bci/bci-minimal:15.6
COPY --from=builder /bitcoin-0.10.0/src/bitcoin-cli /usr/local/bin
COPY --from=builder /bitcoin-0.10.0/src/bitcoin-tx /usr/local/bin
COPY --from=builder /bitcoin-0.10.0/src/bitcoind /usr/local/bin
COPY --from=builder /usr/lib64/libevent_pthreads-2.1.so.7 /usr/lib64/
COPY --from=builder /usr/lib64/libevent-2.1.so.7 /usr/lib64/
COPY --from=builder /usr/lib64/libdb_cxx-4.8.so /usr/lib64/
COPY --from=builder /usr/lib64/libsqlite3.so.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_system.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_filesystem.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_program_options.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_thread.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_chrono.so.1.57.0 /usr/lib64/
COPY --from=builder /usr/lib64/libssl.so.1.0.0 /usr/lib64/
COPY --from=builder /usr/lib64/libcrypto.so.1.0.0 /usr/lib64/

COPY entrypoint.sh /entrypoint.sh
COPY bitcoin.conf /root/.bitcoin/bitcoin.conf
RUN chmod +x /entrypoint.sh
EXPOSE 8332 8333 18332 18333
ENTRYPOINT ["/entrypoint.sh"]
