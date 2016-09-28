#!/bin/bash

# Bash Error Handling / Bash Strict Mode
set -eu
IFS=$'\n\t'

# Plesk Reconfiguration + Nginx Reload
/usr/local/psa/admin/bin/httpdmng --reconfigure-all
service nginx reload
