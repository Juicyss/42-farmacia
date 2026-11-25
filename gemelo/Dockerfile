# Gemelo digital de la Farmacia #42 — SWI-Prolog con Janus + matplotlib
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends software-properties-common gpg-agent \
 && add-apt-repository -y ppa:swi-prolog/stable \
 && apt-get update && apt-get install -y --no-install-recommends swi-prolog-nox python3-matplotlib \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . .
RUN swipl -g run_tests -t halt tests/reglas_tests.pl
EXPOSE 8042
CMD ["swipl", "servidor.pl", "8042"]
