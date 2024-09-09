FROM registry.suse.com/bci/bci-base:15.6 AS builder
RUN zypper ref -s && zypper --non-interactive install git wget libevent-devel awk libdb-4_8-devel sqlite3-devel libleveldb1 clang7 gcc-c++ && zypper --non-interactive install -t pattern devel_basis #prereqs
RUN wget https://sourceforge.net/projects/boost/files/boost/1.57.0/boost_1_57_0.tar.gz/download -O boost_1_57_0.tar.gz #boost1.57.0
RUN tar -xvf boost_1_57_0.tar.gz #boost1.57.0
ENV BOOST_ROOT=/boost_1_57_0
WORKDIR /boost_1_57_0

RUN chmod +x bootstrap.sh #boost1.57.0
RUN ./bootstrap.sh #boost1.57.0
RUN ./b2  -j"$(($(nproc) + 1))" || ./b2 install || ./b2 headers #boost1.57.0
RUN git clone https://github.com/bitcoin/bitcoin.git /bitcoin #bitcoin_git
WORKDIR /bitcoin
RUN git fetch --all --tags
RUN git checkout tags/v0.9.2 -b v0.9.2 #v0.9.2
RUN zypper addrepo https://download.opensuse.org/repositories/home:MaxxedSUSE:Compiler-Tools-15.6/15.6/home:MaxxedSUSE:Compiler-Tools-15.6.repo
RUN zypper --gpg-auto-import-keys ref -s #gcc6
RUN zypper --non-interactive install libopenssl-1_0_0-devel #openssl1.0
RUN sed -i '1i#include <stdarg.h>' /bitcoin/src/leveldb/util/posix_logger.h
RUN sed -i 's/va_copy/__va_copy/' /bitcoin/src/leveldb/util/posix_logger.h

#RUN sed -i 's/base58Prefixes\[PUBKEY_ADDRESS\] = list_of(0)/base58Prefixes[PUBKEY_ADDRESS] = std::vector<unsigned char>(1, 0)/' src/chainparams.cpp
#RUN sed -i 's/base58Prefixes\[SCRIPT_ADDRESS\] = list_of(5)/base58Prefixes[SCRIPT_ADDRESS] = std::vector<unsigned char>(1, 5)/' src/chainparams.cpp
#RUN sed -i 's/base58Prefixes\[SECRET_KEY\] = list_of(128)/base58Prefixes[SECRET_KEY] = std::vector<unsigned char>(1, 128)/' src/chainparams.cpp
#RUN sed -i 's/base58Prefixes\[EXT_PUBLIC_KEY\] = list_of(0x04)(0x88)(0xB2)(0x1E)/base58Prefixes[EXT_PUBLIC_KEY] = std::vector<unsigned char>{0x04, 0x88, 0xb2, 0x1e}/' src/chainparams.cpp
#RUN sed -i 's/base58Prefixes\[EXT_SECRET_KEY\] = list_of(0x04)(0x88)(0xAD)(0xE4)/base58Prefixes[EXT_SECRET_KEY] = std::vector<unsigned char>{0x04, 0x88, 0xad, 0xe4}/' src/chainparams.cpp
#RUN sed -i 's/base58Prefixes\[PUBKEY_ADDRESS\] = list_of(111)/base58Prefixes[PUBKEY_ADDRESS] = std::vector<unsigned char>(1, 111)/' src/chainparams.cpp
#RUN sed -i 's/base58Prefixes\[SCRIPT_ADDRESS\] = list_of(196)/base58Prefixes[SCRIPT_ADDRESS] = std::vector<unsigned char>(1, 196)/' src/chainparams.cpp
#RUN sed -i 's/base58Prefixes\[SECRET_KEY\] = list_of(239)/base58Prefixes[SECRET_KEY] = std::vector<unsigned char>(1, 239)/' src/chainparams.cpp
#RUN sed -i 's/base58Prefixes\[EXT_PUBLIC_KEY\] = list_of(0x04)(0x35)(0x87)(0xCF)/base58Prefixes[EXT_PUBLIC_KEY] = std::vector<unsigned char>{0x04, 0x35, 0x87, 0xCF}/' src/chainparams.cpp
#RUN sed -i 's/base58Prefixes\[EXT_SECRET_KEY\] = list_of(0x04)(0x35)(0x83)(0x94)/base58Prefixes[EXT_SECRET_KEY] = std::vector<unsigned char>{0x04, 0x35, 0x83, 0x94}/' src/chainparams.cpp

COPY patch_mocacinno_chainparams /bitcoin
RUN patch /bitcoin/src/chainparams.cpp < patch_mocacinno_chainparams

RUN ./autogen.sh #v0.9.2
RUN ldconfig
#RUN ln -s /boost_1_57_0/stage/lib/libboost_system.so.1.57.0 /usr/lib64
RUN ./configure  --with-cli --with-daemon CXX="g++ -std=c++11" #v0.9.2
#RUN sed -i '1i#ifndef va_copy\n#define va_copy(dest, src) ((dest) = (src))\n#endif' /bitcoin/src/leveldb/util/posix_logger.h

RUN make -j "$(($(nproc) + 1))" #v0.9.2
WORKDIR /bitcoin/src
RUN strip bitcoind && strip bitcoin-cli

FROM registry.suse.com/bci/bci-minimal:15.6
COPY --from=builder /bitcoin/src/bitcoin-cli /usr/local/bin
COPY --from=builder /bitcoin/src/bitcoind /usr/local/bin
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
