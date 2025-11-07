FROM ubuntu:24.04

ARG PYTHON_VERSION=3.12.3
ARG ANSIBLE_VERSION=9.2.0
# ARG PYTHON_VERSION=2.7.18
# ARG ANSIBLE_VERSION=2.9.27

ENV DEBIAN_FRONTEND=noninteractive \
    PYENV_ROOT=/opt/pyenv

ENV PATH=${PYENV_ROOT}/shims:${PYENV_ROOT}/bin:${PATH}

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       make \
       gcc \
       curl \
       git \
       ca-certificates \
       openssh-server \
       openssh-client \
       sudo \
       gosu \
       vim \
       wget \
       libssl-dev \
       zlib1g-dev \
       libbz2-dev \
       libreadline-dev \
       libsqlite3-dev \
       libncursesw5-dev \
       libncurses5-dev \
       xz-utils \
       tk-dev \
       libffi-dev \
       liblzma-dev \
       uuid-runtime \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/pyenv/pyenv.git ${PYENV_ROOT} \
    && ${PYENV_ROOT}/bin/pyenv install --skip-existing ${PYTHON_VERSION} \
    && ${PYENV_ROOT}/bin/pyenv global ${PYTHON_VERSION} \
    && ${PYENV_ROOT}/bin/pyenv rehash \
    && ${PYENV_ROOT}/bin/pyenv exec python -m ensurepip \
    && ${PYENV_ROOT}/bin/pyenv exec python -m pip install --no-cache-dir --upgrade pip \
    && ${PYENV_ROOT}/bin/pyenv exec pip install --no-cache-dir ansible==${ANSIBLE_VERSION}

RUN mkdir -p /etc/profile.d \
    && echo 'export PYENV_ROOT="/opt/pyenv"' > /etc/profile.d/pyenv.sh \
    && echo 'export PATH="${PYENV_ROOT}/shims:${PYENV_ROOT}/bin:$PATH"' >> /etc/profile.d/pyenv.sh \
    && chmod +x /etc/profile.d/pyenv.sh

RUN useradd -ms /bin/bash ansible \
    && echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansible \
    && chmod 440 /etc/sudoers.d/ansible

RUN mkdir -p /var/run/sshd

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

