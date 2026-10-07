#!/usr/bin/env bash
# Strip Node.js deprecation noise from an act log (nothing else is changed).
grep -vE 'DeprecationWarning|trace-deprecation|Running pip as the .root. user' "$1"
