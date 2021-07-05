FROM ubuntu:latest as builder

ENV DEBIAN_FRONTEND="noninteractive"

RUN apt-get update && apt-get install -y build-essential git pkg-config libseccomp-dev
RUN git clone https://github.com/solo5/solo5 && \
    cd solo5 && \
    ./configure.sh && \
    make

FROM ghcr.io/openfaas/classic-watchdog:0.1.4 as watchdog

FROM ubuntu:20.04

RUN mkdir -p /home/app

COPY --from=watchdog /fwatchdog /usr/bin/fwatchdog
RUN chmod +x /usr/bin/fwatchdog

RUN adduser app && adduser app app
RUN chown app /home/app

WORKDIR /home/app

USER app


COPY --from=builder /solo5/tenders/hvt/solo5-hvt /solo5-hvt
COPY --from=builder /solo5/tenders/spt/solo5-spt /solo5-spt
COPY --from=builder /solo5/tests/test_hello/test_hello.hvt /test_hello.hvt
COPY --from=builder /solo5/tests/test_hello/test_hello.spt /test_hello.spt

EXPOSE 8080

HEALTHCHECK --interval=3s CMD [ -e /tmp/.lock ] || exit 1

CMD ["fwatchdog"]
