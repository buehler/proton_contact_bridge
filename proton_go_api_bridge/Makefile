GO_FILES := $(shell find ./src -name "*.go")

.PHONY: all
all: build protobuf

.PHONY: build
build: lib/src/bindings.g.dart

.PHONY: clean
clean:
	rm -f src/bridge.h
	rm -f lib/src/bindings.g.dart

src/bridge.h: $(GO_FILES)
	go tool cgo -exportheader src/bridge.h src/bridge.go

lib/src/bindings.g.dart: src/bridge.h
	dart run ffigen --config ffigen.yaml

src/protobuf/proton:
	mkdir -p src/protobuf/proton

lib/src/protobuf/proton:
	mkdir -p lib/src/protobuf/proton

PROTO_FILES := $(shell find ./protobuf -type f -name '*.proto')
PROTO_FILES := $(PROTO_FILES:./%=%)
GO_PROTO_FILES := $(addprefix src/,$(patsubst %.proto,%.pb.go,$(PROTO_FILES)))
DART_PROTO_FILES := $(addprefix lib/src/,$(patsubst %.proto,%.pb.dart,$(PROTO_FILES)) $(patsubst %.proto,%.pbenum.dart,$(PROTO_FILES)) $(patsubst %.proto,%.pbjson.dart,$(PROTO_FILES)))

.PHONY: protobuf
protobuf: go dart

.PHONY: go
go:
	protoc --proto_path=protobuf --go_out=src/protobuf/proton --go_opt=paths=source_relative $(PROTO_FILES)

.PHONY: dart
dart:
	protoc --proto_path=protobuf --dart_out=lib/src/protobuf/proton $(PROTO_FILES)
