FROM registry.suse.com/bci/bci-base:15.7 AS builder

RUN zypper addrepo https://download.opensuse.org/repositories/devel:gcc/SLE-15/devel:gcc.repo
RUN zypper addrepo https://download.opensuse.org/repositories/home:MaxxedSUSE:Compiler-Tools-15.6/15.6/home:MaxxedSUSE:Compiler-Tools-15.6.repo
RUN zypper addrepo https://download.opensuse.org/repositories/devel:libraries:c_c++/15.7/devel:libraries:c_c++.repo
RUN zypper --gpg-auto-import-keys ref -s
RUN zypper --non-interactive install gcc7 gcc7-c++ make automake makeinfo git gawk libdb-4_8-devel libopenssl-1_0_0-devel wget libicu-devel libminiupnpc-devel libupnp-devel patch unzip

#gcc 7
ENV CC=gcc-7
ENV CXX=g++-7
ENV PERL5LIB=.
RUN ln -s /usr/bin/gcc-7 /usr/bin/gcc && \
    ln -s /usr/bin/g++-7 /usr/bin/g++


#boost 1.57.0
WORKDIR /
RUN wget https://sourceforge.net/projects/boost/files/boost/1.57.0/boost_1_57_0.tar.gz/download -O boost_1_57_0.tar.gz
RUN tar -xvf boost_1_57_0.tar.gz
ENV BOOST_ROOT=/boost_1_57_0
WORKDIR /boost_1_57_0
RUN chmod +x bootstrap.sh
RUN ./bootstrap.sh
RUN ./b2  -j"$(($(nproc) + 1))" || ./b2 -j"$(($(nproc) + 1))" install || ./b2 -j"$(($(nproc) + 1))" headers


#bitcoin v0.6.1
WORKDIR /
RUN wget https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.6.1.zip && \
    unzip v0.6.1.zip
WORKDIR /bitcoin-0.6.1/src
COPY patch_mocacinno_net /bitcoin-0.6.1/src/patch_mocacinno_net
COPY patch_mocacinno_strlcpy /bitcoin-0.6.1/src/patch_mocacinno_strlcpy
RUN patch net.cpp < patch_mocacinno_net
RUN patch strlcpy.h < patch_mocacinno_strlcpy
RUN make -j"$(($(nproc) + 1))" -f makefile.unix BOOST_INCLUDE_PATH=/boost_1_57_0 CXXFLAGS="-DHAVE_DECL_STRLCPY=1 -DHAVE_DECL_STRLCAT=1 -Wno-deprecated-declarations"
RUN strip bitcoind 

FROM registry.suse.com/bci/bci-minimal:15.7
COPY --from=builder /bitcoin-0.6.1/src/bitcoind /usr/local/bin
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
LABEL org.opencontainers.image.revision="manual-trigger-20250915"
ENTRYPOINT ["/entrypoint.sh"]
