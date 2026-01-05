FROM registry.suse.com/bci/bci-base:15.7 AS builder

RUN zypper --non-interactive ref && \
    zypper --non-interactive in -y curl ca-certificates
WORKDIR /etc/pki/rpm-gpg/
RUN curl -fsSL https://raw.githubusercontent.com/mocacinno/bitcoin_core_docker_prereqs/refs/heads/gh-pages/mocacinno_pubkey.asc -o /etc/pki/rpm-gpg/RPM-GPG-KEY-myrepo && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-myrepo

RUN zypper addrepo -f https://github.com/mocacinno/bitcoin_core_docker_prereqs/raw/refs/heads/gh-pages/x86_64/ mocacinno_x86_64 && \
    zypper addrepo -f https://github.com/mocacinno/bitcoin_core_docker_prereqs/raw/refs/heads/gh-pages/noarch/ mocacinno_noarch
RUN zypper --gpg-auto-import-keys ref -s
RUN zypper --non-interactive install gcc9 gcc9-c++ make automake makeinfo git gawk libdb-4_8-devel libopenssl-1_0_0-devel wget libicu-devel libminiupnpc-devel libupnp-devel patch unzip

#gcc 9
ENV CC=gcc-9
ENV CXX=g++-9
ENV PERL5LIB=.
RUN ln -s /usr/bin/gcc-9 /usr/bin/gcc
RUN ln -s /usr/bin/g++-9 /usr/bin/g++

#boost 1.57.0
WORKDIR /
RUN wget https://github.com/mocacinno/bitcoin_core_docker_prereqs/raw/refs/heads/gh-pages/boost_1_57_0.tar.gz -O boost_1_57_0.tar.gz
RUN tar -xvf boost_1_57_0.tar.gz
ENV BOOST_ROOT=/boost_1_57_0
WORKDIR /boost_1_57_0
RUN chmod +x bootstrap.sh
RUN ./bootstrap.sh
RUN ./b2  -j"$(($(nproc) + 1))" || ./b2 -j"$(($(nproc) + 1))" install || ./b2 -j"$(($(nproc) + 1))" headers

#bitcoin v0.8.0
WORKDIR /
RUN wget https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.8.0.zip && \
    unzip v0.8.0.zip
WORKDIR /bitcoin-0.8.0/src
COPY patch_mocacinno_net /bitcoin-0.8.0/src/patch_mocacinno_net
RUN patch net.cpp < patch_mocacinno_net
RUN make -j "$(($(nproc) + 1))" -f makefile.unix BOOST_INCLUDE_PATH=/boost_1_57_0
WORKDIR /bitcoin-0.8.0/src
RUN strip bitcoind 

FROM registry.suse.com/bci/bci-minimal:15.7
COPY --from=builder /bitcoin-0.8.0/src/bitcoind /usr/local/bin
COPY --from=builder /usr/lib64/libdb_cxx-4.8.so /usr/lib64/
COPY --from=builder /usr/lib64/libsqlite3.so.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_system.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_filesystem.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_program_options.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_thread.so.1.57.0 /usr/lib64/
COPY --from=builder /boost_1_57_0/stage/lib/libboost_chrono.so.1.57.0 /usr/lib64/
COPY --from=builder /usr/lib64/libssl.so.1.0.0 /usr/lib64/
COPY --from=builder /usr/lib64/libcrypto.so.1.0.0 /usr/lib64/
COPY --from=builder /usr/lib64/libminiupnpc.so.17 /usr/lib64/

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 8332 8333 15332 15333
RUN echo 'bitcoinuser:x:10001:10001:Bitcoin User:/home/bitcoinuser:/bin/sh' >> /etc/passwd \
 && echo 'bitcoinuser:x:10001:' >> /etc/group \
 && mkdir -p /home/bitcoinuser \
 && chown -R 10001:10001 /home/bitcoinuser
COPY bitcoin.conf /home/bitcoinuser/.bitcoin/bitcoin.conf
RUN chown -R bitcoinuser:bitcoinuser /home/bitcoinuser
USER bitcoinuser
LABEL org.opencontainers.image.revision="manual-trigger-20260105"
LABEL waitforfinish="true"
ENTRYPOINT ["/entrypoint.sh"]
