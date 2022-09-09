FROM ubuntu:focal as app

# System requirements

RUN apt-get update && \
apt-get install -y software-properties-common && \
apt-add-repository -y ppa:deadsnakes/ppa && apt-get update && \
apt-get upgrade -qy && apt-get install language-pack-en locales git \
python3.8-dev python3-virtualenv libmysqlclient-dev libssl-dev build-essential wget unzip -qy && \
rm -rf /var/lib/apt/lists/*

# Python is Python3.
RUN ln -s /usr/bin/python3 /usr/bin/python

# Use UTF-8.
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8


ARG COMMON_CFG_DIR="/edx/etc"
ENV XQUEUE_CFG_DIR="${COMMON_CFG_DIR}/xqueue"

ARG COMMON_APP_DIR="/edx/app"
ARG XQUEUE_SERVICE_NAME="xqueue"
ARG XQUEUE_APP_DIR="${COMMON_APP_DIR}/xqueue"
ENV XQUEUE_APP_DIR="${COMMON_APP_DIR}/xqueue"
ENV SUPERVISOR_APP_DIR="${COMMON_APP_DIR}/supervisor"
ENV XQUEUE_VENV_DIR="${COMMON_APP_DIR}/xqueue/venvs/xqueue"
ARG SUPERVISOR_VENV_DIR="${SUPERVISOR_APP_DIR}/venvs/supervisor"
ARG SUPERVISOR_AVAILABLE_DIR="${SUPERVISOR_APP_DIR}/conf.available.d"
ARG SUPERVISOR_VENV_BIN="${SUPERVISOR_VENV_DIR}/bin"
ARG SUPEVISOR_CTL="${SUPERVISOR_VENV_BIN}/supervisorctl"
ARG SUPERVISOR_CFG_DIR="${SUPERVISOR_APP_DIR}/conf.d"
ENV XQUEUE_CODE_DIR="${XQUEUE_APP_DIR}/xqueue"
ARG SUPERVISOR_VERSION="4.2.1"

ENV PATH="$XQUEUE_VENV_DIR/bin:$PATH"

RUN addgroup xqueue
RUN adduser --disabled-login --disabled-password xqueue --ingroup xqueue


RUN mkdir -p "$XQUEUE_APP_DIR"

# Working directory will be root of repo.
WORKDIR ${XQUEUE_CODE_DIR}

RUN virtualenv -p python3.8 --always-copy ${XQUEUE_VENV_DIR}
RUN virtualenv -p python3.8 --always-copy ${SUPERVISOR_VENV_DIR}


#install supervisor and deps in its virtualenv
RUN . ${SUPERVISOR_VENV_BIN}/activate && \
  pip install supervisor==${SUPERVISOR_VERSION} backoff==1.4.3 boto==2.48.0 && \
  deactivate

# create supervisor job
COPY /configuration_files/supervisor.conf /etc/systemd/system/supervisor.service
COPY /configuration_files/supervisorctl ${SUPERVISOR_VENV_BIN}/supervisorctl

# Copy just Python requirements & install them.
COPY requirements ${XQUEUE_CODE_DIR}/requirements
COPY requirements.txt ${XQUEUE_APP_DIR}/requirements.txt
COPY Makefile ${XQUEUE_CODE_DIR}

#Configurations from edx_service task
RUN mkdir ${XQUEUE_APP_DIR}/data/
RUN mkdir ${XQUEUE_APP_DIR}/staticfiles/
RUN mkdir -p /edx/var/xqueue/
# Log dir
RUN mkdir -p /edx/var/log/


ENV XQUEUE_CFG="${COMMON_CFG_DIR}/xqueue.yml"
COPY configuration_files/xqueue.yml ${XQUEUE_CFG}

# xqueue service config commands below
RUN pip install -r ${XQUEUE_APP_DIR}/requirements.txt

# After the requirements so changes to the code will not bust the image cache
COPY . ${XQUEUE_CODE_DIR}/

COPY scripts/devstack.sh "$XQUEUE_APP_DIR/devstack.sh"
# Enable supervisor script
COPY scripts/xqueue.sh $XQUEUE_APP_DIR/xqueue.sh
COPY /configuration_files/xqueue.conf ${SUPERVISOR_AVAILABLE_DIR}/xqueue.conf
COPY /configuration_files/xqueue.conf ${SUPERVISOR_CFG_DIR}/xqueue.conf
# Manage.py symlink
COPY /manage.py /edx/bin/manage.xqueue

RUN chown xqueue:xqueue "$XQUEUE_APP_DIR/devstack.sh" && chmod a+x "$XQUEUE_APP_DIR/devstack.sh"

# placeholder file for the time being unless devstack provisioning scripts need it.
RUN touch ${XQUEUE_APP_DIR}/xqueue_env
# Expose ports.
EXPOSE 8040


FROM app as production

ENV DJANGO_SETTINGS_MODULE xqueue.settings.production

COPY scripts/xqueue.sh "$XQUEUE_APP_DIR/xqueue.sh"

#CMD ["gunicorn", "--workers=2", "--name", "xqueue", "-c", "/edx/app/xqueue/xqueue/xqueue/docker_gunicorn_configuration.py", "--log-file", "-", "--max-requests=1000", "xqueue.wsgi:application"]
#CMD ["sh", "-c", "gunicorn", "--workers=2", "--name", "xqueue", "-c", "${XQUEUE_CODE_DIR}/docker_gunicorn_configuration.py", "--log-file", "-", "--max-requests=1000", "xqueue.wsgi:application"]
ENTRYPOINT ["/edx/app/xqueue/xqueue.sh"]


FROM app as dev

# xqueue service config commands below
RUN pip install -r ${XQUEUE_CODE_DIR}/requirements/dev.txt


ENV DJANGO_SETTINGS_MODULE xqueue.settings.devstack

ENTRYPOINT ["/edx/app/xqueue/devstack.sh"]
CMD ["start"]
