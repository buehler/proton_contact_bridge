GO_FILES := $(shell find ./src -name "*.go")

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
