#!/usr/bin/env bash

# Removes lib.a files cached under $GOPATH.
# Sometimes these are not regenerated by go when doing `go run`

rm ${GOPATH}/pkg/*/github.com/dollarydooslab/dollarydoos-master/src/*.a
rm ${GOPATH}/pkg/*/github.com/dollarydooslab/dollarydoos-master/src/lib/*.a
rm ${GOPATH}/pkg/*/github.com/dollarydooslab/*.a
