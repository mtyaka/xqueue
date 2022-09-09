#!/usr/bin/env bash


source /edx/app/xqueue/xqueue_env

# We exec so that gunicorn is the child of supervisor and can be managed properly
exec /edx/app/xqueue/venvs/xqueue/bin/gunicorn --pythonpath=/edx/app/xqueue/xqueue/ -b 127.0.0.1:8110 -w 2 --timeout=300  xqueue.wsgi:application
