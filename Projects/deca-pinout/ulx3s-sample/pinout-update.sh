#!/usr/bin/env bash

while  [ 1 -eq 1 ]; do 
  inotifywait -e modify styles.css pinout_ulx3s.py data.py
  echo "Change!"
  rm pinout_ulx3s.svg
  python3 -m pinout.manager --export pinout_ulx3s pinout_ulx3s.svg
done
