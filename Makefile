TARGETS := kern/ssldump
TARGETS += kern/bash
#TARGETS += kern/mysqld57

# Generate file name-scheme based on TARGETS
KERN_SOURCES = ${TARGETS:=_kern.c}
KERN_OBJECTS = ${KERN_SOURCES:.c=.o}

VERSION = $(shell git rev-parse --short HEAD || echo "GitNotFound")
DATETIME = $(shell date +"%Y/%m/%d-%H:%M:%S")

# @TODO 编译器版本检测，llvm检测，系统版本检测等

LLC ?= llc
CLANG ?= clang
EXTRA_CFLAGS ?= -O2 -mcpu=v1 -nostdinc -Wno-pointer-sign

BPFHEADER = -I./kern \

all: $(KERN_OBJECTS) assets build
	@echo $(shell date)

.PHONY: clean assets

clean:
	rm -f user/bytecode/*.d
	rm -f user/bytecode/*.o
	rm -f assets/ebpf_probe.go
	rm -f bin/ecapture

$(KERN_OBJECTS): %.o: %.c
	$(CLANG) $(EXTRA_CFLAGS) \
		$(BPFHEADER) \
		-target bpfel -c $< -o $(subst kern/,user/bytecode/,$@) \
		-fno-ident -fdebug-compilation-dir . -g -D__BPF_TARGET_MISSING="GCC error \"The eBPF is using target specific macros, please provide -target\"" \
		-MD -MP

assets:
	go run github.com/shuLhan/go-bindata/cmd/go-bindata -pkg assets -o "assets/ebpf_probe.go" $(wildcard ./user/bytecode/*.o)

build:
	CGO_ENABLED=0 go build -ldflags "-X 'ecapture/cli/cmd.GitVersion=$(VERSION)' -X 'ecapture/cli/cmd.ReleaseDate=$(DATETIME)'" -o bin/ecapture .