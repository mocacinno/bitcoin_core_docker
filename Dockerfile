FROM registry.suse.com/bci/bci-base:15.6 AS builder

RUN zypper ref -s && zypper --non-interactive install git wget unzip awk cmake gcc14 gcc14-c++ autoconf automake binutils  bison cpp14 flex gdbm-devel gettext-tools glibc-devel libtool m4 make makeinfo ncurses-devel patch zlib-devel patch pkg-config sqlite3-devel libevent-devel python311 valgrind
RUN ln -s /usr/bin/gcc-14 /usr/bin/gcc
RUN ln -s /usr/bin/g++-14 /usr/bin/g++

#bitcoin v29.0
WORKDIR /
RUN wget https://github.com/bitcoin/bitcoin/archive/refs/tags/v29.0.zip && \
    unzip v29.0.zip
WORKDIR /bitcoin-29.0
RUN make -C depends NO_QT=1
RUN cmake -B build --toolchain /bitcoin-29.0/depends/x86_64-pc-linux-gnu/toolchain.cmake
RUN cmake --build build -j "$(($(nproc) + 1))"
WORKDIR /bitcoin-29.0/build/bin
RUN strip bitcoin-util && strip bitcoin-cli && strip bitcoin-tx && strip bitcoin-wallet && strip bitcoind && strip test_bitcoin
#docker run -it --network none

FROM registry.suse.com/bci/bci-minimal:15.6
COPY --from=builder /bitcoin-29.0/build/bin/bitcoin-util /usr/local/bin
COPY --from=builder /bitcoin-29.0/build/bin/bitcoin-cli /usr/local/bin
COPY --from=builder /bitcoin-29.0/build/bin/bitcoin-tx /usr/local/bin
COPY --from=builder /bitcoin-29.0/build/bin/bitcoin-wallet /usr/local/bin
COPY --from=builder /bitcoin-29.0/build/bin/bitcoind /usr/local/bin
COPY --from=builder /bitcoin-29.0/build/bin/test_bitcoin /usr/local/bin

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 8332 8333 18332 18333
ENTRYPOINT ["/entrypoint.sh"]
