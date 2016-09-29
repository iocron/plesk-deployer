#!/bin/bash

set -e
find . -exec grep -nH $1 . {} \; -print 2>/dev/null
