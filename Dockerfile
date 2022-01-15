FROM ubuntu:18.04 as builder

ENV DEBIAN_FRONTEND="noninteractive"

RUN apt-get update && apt-get install -y build-essential git pkg-config libseccomp-dev \
	libz-dev bin86 bison flex wget bc libelf-dev libssl-dev \
	init udev kmod unzip python3 && apt-get clean

# build unikraft
RUN mkdir -p unikraft/libs unikraft/apps && \
	cd unikraft && \
	git clone https://github.com/cloudkernels/unikraft.git -b vaccel && \
	cd apps && \
	git clone https://github.com/cloudkernels/unikraft_app_classify.git && \
        cd unikraft_app_classify && cp vaccel_config .config && \
        make

FROM ghcr.io/openfaas/classic-watchdog:0.1.4 as watchdog

FROM nubificus/jetson-inference

RUN mkdir /guest && apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -yy eatmydata && \
	DEBIAN_FRONTEND=noninteractive eatmydata \
	apt-get install -y --no-install-recommends \
		bison \
		flex \
		build-essential \
		libglib2.0-dev \
		libfdt-dev \
		libpixman-1-dev \
		zlib1g-dev \
		pkg-config \
		iproute2 \
		libcap-ng-dev \
		libattr1-dev \
		genisoimage \
		unzip \
		apt-transport-https ca-certificates \
		$(apt-get -s build-dep qemu | egrep ^Inst | fgrep '[all]' | cut -d\  -f2) \
	&& rm -rf /var/lib/apt/lists/* && update-ca-certificates

# Build & install vaccelrti
RUN git clone https://${TOKEN}:x-oauth-basic@github.com/cloudkernels/vaccelrt && \
	cd vaccelrt && git checkout 5c3b9adf072965b3c8c5657e939fad18707f883d && \
	git submodule update --init && mkdir build && cd build && \
	cmake -DCMAKE_INSTALL_PREFIX=/.local -DBUILD_PLUGIN_JETSON=ON .. && \
	make && make install && \
	cd ../..

# Build & install QEMU w/ vAccel backend
RUN git clone https://github.com/cloudkernels/qemu-vaccel.git \
	-b vaccelrt_legacy_virtio && cd qemu-vaccel && \
	git submodule update --init && \
	./configure --extra-cflags="-I /.local/include" --extra-ldflags="-L/.local/lib" --target-list=x86_64-softmmu --enable-virtfs && \
	make -j$(nproc) && make install && \
	cd .. && rm -rf qemu-vaccel

RUN mkdir -p /usr/local/share/imagenet-models/ && cd /usr/local/share/imagenet-models/ && \
	wget https://github.com/nubificus/qemu-x86-build/releases/download/v0.01/networks.tar.bz2 && \
	tar xjf networks.tar.bz2 && \
	cp /usr/local/share/jetson-inference/data/networks/* /usr/local/share/imagenet-models/networks && \
	cd /

COPY --from=watchdog /fwatchdog /usr/bin/fwatchdog
RUN chmod +x /usr/bin/fwatchdog

##RUN adduser app && adduser app app && usermod -a -G sudo app
##RUN chown app /home/app
##
##WORKDIR /home/app
##
##USER app

COPY --from=builder /unikraft/apps/unikraft_app_classify/build/unikraft_app_classify_kvm-x86_64 /classify_kvm-x86_64
COPY data /data
COPY qemu_run.sh .

EXPOSE 8080

HEALTHCHECK --interval=3s CMD [ -e /tmp/.lock ] || exit 1

ENV write_debug="true"
#ENV fprocess="xargs qemu_run.sh"
CMD ["fwatchdog"]
