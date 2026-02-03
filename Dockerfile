FROM registry.suse.com/bci/bci-base:15.7 AS builder

RUN zypper --non-interactive ref && \
    zypper --non-interactive in -y curl ca-certificates
WORKDIR /etc/pki/rpm-gpg/
RUN curl -fsSL https://raw.githubusercontent.com/mocacinno/bitcoin_core_docker_prereqs/refs/heads/gh-pages/mocacinno_pubkey.asc -o /etc/pki/rpm-gpg/RPM-GPG-KEY-myrepo && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-myrepo

RUN zypper addrepo --priority 200 -f https://github.com/mocacinno/bitcoin_core_docker_prereqs/raw/refs/heads/gh-pages/x86_64/ mocacinno_x86_64 && \
    zypper addrepo --priority 200 -f https://github.com/mocacinno/bitcoin_core_docker_prereqs/raw/refs/heads/gh-pages/noarch/ mocacinno_noarch
RUN zypper --gpg-auto-import-keys ref -s
RUN zypper ref -s && zypper --non-interactive install git wget libevent-devel gawk libdb-4_8-devel sqlite3-devel libleveldb1 clang7 gcc14-c++ libopenssl-1_0_0-devel unzip && zypper --non-interactive install -t pattern devel_basis
RUN ln -s /usr/bin/g++-14 /usr/bin/g++

#boost 1.57.0
WORKDIR /
RUN wget https://github.com/mocacinno/bitcoin_core_docker_prereqs/raw/refs/heads/gh-pages/boost_1_57_0.tar.gz -O boost_1_57_0.tar.gz
RUN tar -xvf boost_1_57_0.tar.gz
ENV BOOST_ROOT=/boost_1_57_0
WORKDIR /boost_1_57_0
RUN chmod +x bootstrap.sh
RUN ./bootstrap.sh
RUN ./b2  -j"$(($(nproc) + 1))" || ./b2 -j"$(($(nproc) + 1))" install || ./b2 -j"$(($(nproc) + 1))" headers


#bitcoin v0.9.2
WORKDIR /
RUN wget https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.9.2.zip && \
    unzip v0.9.2.zip
WORKDIR /bitcoin-0.9.2
RUN sed -i '1i#include <stdarg.h>' /bitcoin-0.9.2/src/leveldb/util/posix_logger.h
RUN sed -i 's/va_copy/__va_copy/' /bitcoin-0.9.2/src/leveldb/util/posix_logger.h
COPY patch_mocacinno_chainparams /bitcoin-0.9.2
RUN patch /bitcoin-0.9.2/src/chainparams.cpp < patch_mocacinno_chainparams
RUN ./autogen.sh
RUN ldconfig
RUN ./configure  --with-cli --with-daemon CXX="g++ -std=c++11"

RUN make -j "$(($(nproc) + 1))"
WORKDIR /bitcoin-0.9.2/src
RUN strip bitcoind && strip bitcoin-cli

FROM registry.suse.com/bci/bci-minimal:15.7
COPY --from=builder /bitcoin-0.9.2/src/bitcoin-cli /usr/local/bin
COPY --from=builder /bitcoin-0.9.2/src/bitcoind /usr/local/bin
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
RUN chmod +x /entrypoint.sh
EXPOSE 8332 8333 18332 18333
RUN echo 'bitcoinuser:x:10001:10001:Bitcoin User:/home/bitcoinuser:/bin/sh' >> /etc/passwd \
 && echo 'bitcoinuser:x:10001:' >> /etc/group \
 && mkdir -p /home/bitcoinuser \
 && chown -R 10001:10001 /home/bitcoinuser
COPY bitcoin.conf /home/bitcoinuser/.bitcoin/bitcoin.conf
RUN chown -R bitcoinuser:bitcoinuser /home/bitcoinuser
USER bitcoinuser
LABEL org.opencontainers.image.revision="manual-trigger-20260203"
ENTRYPOINT ["/entrypoint.sh"]
