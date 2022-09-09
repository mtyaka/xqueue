#!/usr/bin/env bash

# Ansible managed

COMMAND=$1

case $COMMAND in
    start)
        /edx/app/supervisor/venvs/supervisor/bin/supervisord -n --configuration /edx/app/supervisor/supervisord.conf
        ;;
    open)
        . /edx/app/xqueue/venvs/xqueue/bin/activate
        cd /edx/app/xqueue/xqueue

        /bin/bash
        ;;
    exec)
        shift

        . /edx/app/xqueue/venvs/xqueue/bin/activate
        cd /edx/app/xqueue/xqueue

        "$@"
        ;;
    *)
        "$@"
        ;;
esac
