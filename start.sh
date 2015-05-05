#!/bin/bash

PID_FILE=/var/run/haproxy.pid
CFG_FILE=/usr/local/etc/haproxy/haproxy.cfg
CMD=haproxy
FIFO="/tmp/inotify2.fifo"

if [ ! -e "$FIFO" ]
then
mkfifo "$FIFO"
fi

$CMD -p $PID_FILE -f $CFG_FILE -Ds &
HAPROXY_PID=$!

sleep 0.5

echo "Started HAProxy $HAPROXY_PID"
echo "in PID file: $(cat $PID_FILE)"

reload() {
  CHILD_PIDS=`cat $PID_FILE`
  echo "Reloading HAProxy process $HAPROXY_PID ($CHILD_PIDS)"
  $CMD -p $PID_FILE -f $CFG_FILE -Ds -sf $CHILD_PIDS &
  HAPROXY_PID=$!
}

cleanup() {
  echo "Stopping HAProxy..."
  kill $(cat $PID_FILE)
  echo "HAProxy stopped."
  kill $INOTIFY_PID
  rm $FIFO
  exit
}

trap reload SIGUSR2
trap cleanup SIGTERM

inotifywait -q -e create,delete,modify,attrib $CFG_FILE > "$FIFO" &
INOTIFY_PID=$!

while read
do
reload &
done < "$FIFO"

#while true; do
#  wait $HAPROXY_PID
#  echo "Parent HAProxy closed $HAPROXY_PID"
#  sleep 1
#  cat "/proc/$HAPROXY_PID/cmdline" > /dev/null || exit 0
#done
