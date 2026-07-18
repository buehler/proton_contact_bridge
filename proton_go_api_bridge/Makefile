.PHONY: all
all: protobuf build

.PHONY: build
build: lib/src/bindings.g.dart

.PHONY: clean
clean:
	rm -f lib/src/bindings.g.dart

src/native.h:
	make -C src native.h

lib/src/bindings.g.dart: src/native.h
	dart run ffigen --config ffigen.yaml

src/protobuf:
	mkdir -p src/protobuf

lib/src/protobuf:
	mkdir -p lib/src/protobuf

PROTO_FILES := $(shell find ./protobuf -type f -name '*.proto')
PROTO_FILES := $(PROTO_FILES:./%=%)
GO_PROTO_FILES := $(addprefix src/,$(patsubst %.proto,%.pb.go,$(PROTO_FILES)))
DART_PROTO_FILES := $(addprefix lib/src/,$(patsubst %.proto,%.pb.dart,$(PROTO_FILES)) $(patsubst %.proto,%.pbenum.dart,$(PROTO_FILES)) $(patsubst %.proto,%.pbjson.dart,$(PROTO_FILES)))

.PHONY: protobuf
protobuf: go dart

.PHONY: go
go: src/protobuf
	protoc --proto_path=protobuf --go_out=src/protobuf --go_opt=module=proton_go_api_bridge/native/protobuf $(PROTO_FILES)

.PHONY: dart
dart: lib/src/protobuf
	protoc --proto_path=protobuf --dart_out=lib/src/protobuf $(PROTO_FILES)
