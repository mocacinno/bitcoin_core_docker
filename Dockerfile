FROM registry.suse.com/bci/bci-base:15.7 AS builder

RUN zypper ref -s && zypper --non-interactive install git wget unzip awk cmake gcc14 gcc14-c++ autoconf automake binutils  bison cpp14 flex  gettext-tools glibc-devel libtool m4 make makeinfo  patch zlib-devel patch pkg-config python311 valgrind valgrind-devel ccache doxygen
RUN ln -s /usr/bin/gcc-14 /usr/bin/gcc
RUN ln -s /usr/bin/g++-14 /usr/bin/g++

#depends basis v29
WORKDIR /depends
RUN wget https://github.com/bitcoin/bitcoin/archive/refs/tags/v29.1.zip && \
    unzip v29.1.zip
WORKDIR /depends/bitcoin-29.1
RUN make -j"$(($(nproc)+1))" -C depends NO_QT=1 MULTIPROCESS=1

#bitcoin v29.2
WORKDIR /
RUN wget https://github.com/bitcoin/bitcoin/archive/refs/tags/v29.2.zip && \
    unzip v29.2.zip
WORKDIR /bitcoin-29.2
RUN cmake -B build --toolchain /depends/bitcoin-29.1/depends/x86_64-pc-linux-gnu/toolchain.cmake -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_BUILD_TYPE=Release -DENABLE_SQLITE=ON -DCMAKE_PREFIX_PATH=/depends/bitcoin-29.1/depends/x86_64-pc-linux-gnu
RUN cmake --build build -j "$(($(nproc) + 1))" 
WORKDIR /bitcoin-29.2/build/bin
RUN strip bitcoin-util && strip bitcoin-cli && strip bitcoin-tx && strip bitcoin-wallet && strip bitcoind && strip test_bitcoin && strip bitcoin-node

FROM registry.suse.com/bci/bci-micro:latest
COPY --from=builder /bitcoin-29.2/build/bin/bitcoin-util /usr/local/bin
COPY --from=builder /bitcoin-29.2/build/bin/bitcoin-cli /usr/local/bin
COPY --from=builder /bitcoin-29.2/build/bin/bitcoin-tx /usr/local/bin
COPY --from=builder /bitcoin-29.2/build/bin/bitcoin-wallet /usr/local/bin
COPY --from=builder /bitcoin-29.2/build/bin/bitcoind /usr/local/bin
COPY --from=builder /bitcoin-29.2/build/bin/test_bitcoin /usr/local/bin
COPY --from=builder /bitcoin-29.2/build/bin/bitcoin-node /usr/local/bin

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 8332 8333 18332 18333
RUN echo 'bitcoinuser:x:10001:10001:Bitcoin User:/home/bitcoinuser:/bin/sh' >> /etc/passwd \
 && echo 'bitcoinuser:x:10001:' >> /etc/group \
 && mkdir -p /home/bitcoinuser \
 && chown -R 10001:10001 /home/bitcoinuser
USER bitcoinuser
LABEL org.opencontainers.image.revision="manual-trigger-20251203"
ENTRYPOINT ["/entrypoint.sh"]
