GO_FILES := $(shell find ./ -name "*.go")

.PHONY: build
build: native.h

native.h: $(GO_FILES) common_types.h
	GOOS=ios GOARCH=arm64 CGO_ENABLED=1 go build -buildmode=c-archive
	rm -f native.a
