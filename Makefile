
# tools
WASI_SDK_URL = https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-20/wasi-sdk-20.0-linux.tar.gz
WABT_URL = https://github.com/WebAssembly/wabt/releases/download/1.0.33/wabt-1.0.33-ubuntu.tar.gz 

WASMCC = ./wasi-sdk/bin/clang
WASM2WAT = ./wabt/bin/wasm2wat
W2C2 = ./w2c2/build/w2c2/w2c2
W2C2_BASE = ./w2c2/w2c2/w2c2_base.h

THUMBCC = arm-linux-gnueabi-gcc -mthumb --static

# these flags make littlefs standalone
LFSFLAGS += -DLFS_NO_ASSERT
LFSFLAGS += -DLFS_NO_DEBUG
LFSFLAGS += -DLFS_NO_WARN
LFSFLAGS += -DLFS_NO_ERROR
LFSFLAGS += -DLFS_NO_MALLOC

WASMFLAGS += --target=wasm32-wasi
WASMFLAGS += -nostartfiles
WASMFLAGS += -Wl,--no-entry
WASMFLAGS += -Wl,--stack-first

WASMFLAGS += -std=c99
WASMFLAGS += -Os

WASMFLAGS += $(LFSFLAGS)

W2C2FLAGS += -p

THUMBFLAGS += $(LFSFLAGS)


## build
.PHONY: all build
all build: wasm c89

## build lfs.wasm
.PHONY: wasm
wasm:
	mkdir -p littlefs-c89
	# first find exports via regex
	$(strip sed -n \
		-e '/\<lfs_migrate\>/d' \
		-e '/\<lfs_file_open\>/d' \
		-e 's/^\(void\|int\|lfs_ssize_t\|lfs_soff_t\) \<\(lfs_[a-z_]*\)\>.*$$$\
			/-Wl,--export=\2/p' \
		littlefs/lfs.h \
		> littlefs-c89/lfs.exports)
	# compile to wasm
	$(strip \
		$(WASMCC) $(WASMFLAGS) \
			@littlefs-c89/lfs.exports \
			-Ilittlefs littlefs/lfs.c littlefs/lfs_util.c \
			-o littlefs-c89/lfs.wasm)

## build lfs.wat (human readable wasm)
.PHONY: wat
wat: wasm
	$(WASM2WAT) littlefs-c89/lfs.wasm -o littlefs-c89/lfs.wat

## build lfs.c (but c89 this time!)
.PHONY: c89
c89: wasm
	# w2c2 apparently needs this
	cp $(W2C2_BASE) littlefs-c89/w2c2_base.h
	$(W2C2) $(W2C2FLAGS) littlefs-c89/lfs.wasm littlefs-c89/lfs_c89.c

## compile liblfs.a using c89
.PHONY: c89-lib
c89-lib: c89
	# just copy littlefs's Makefile
	cp littlefs/Makefile littlefs-c89/Makefile
	# compile to thumb
	$(strip \
		CC="$(THUMBCC)" \
		CFLAGS="$(THUMBFLAGS) -Wno-unused-label -Wno-unused-parameter" \
		SRC=lfs_c89.c \
		$(MAKE) -C littlefs-c89)

## find c89 code/stack/etc sizes
.PHONY: c89-summary c89-sizes
c89-summary c89-sizes: c89
	# just copy littlefs's Makefile
	cp littlefs/Makefile littlefs-c89/Makefile
	# copy littlefs scripts
	cp -r littlefs/scripts littlefs-c89/scripts
	# compile to thumb
	$(strip \
		CC="$(THUMBCC)" \
		CFLAGS="$(THUMBFLAGS) -Wno-unused-label -Wno-unused-parameter" \
		SRC=lfs_c89.c \
		$(MAKE) -C littlefs-c89 sizes)

## compile liblfs.a using c99
.PHONY: c99-lib
c99-lib:
	# compile to thumb
	$(strip \
		CC="$(THUMBCC)" \
		CFLAGS="$(THUMBFLAGS)" \
		$(MAKE) -C littlefs)

## find c99 code/stack/etc sizes
.PHONY: c99-summary c99-sizes
c99-summary c99-sizes:
	# compile to thumb
	$(strip \
		CC="$(THUMBCC)" \
		CFLAGS="$(THUMBFLAGS)" \
		$(MAKE) -C littlefs sizes)

## compare c99 vs transpiled c89
.PHONY: diff
diff: c99-sizes c89-sizes
	# copy over the c99 results
	cp littlefs/lfs.code.csv littlefs-c89/lfs.code.csv
	cp littlefs/lfs.data.csv littlefs-c89/lfs.data.csv
	cp littlefs/lfs.stack.csv littlefs-c89/lfs.stack.csv
	cp littlefs/lfs.structs.csv littlefs-c89/lfs.structs.csv
	# and compare
	$(strip \
		CC="$(THUMBCC)" \
		CFLAGS="$(THUMBFLAGS) -Wno-unused-label -Wno-unused-parameter" \
		SRC=lfs_c89.c \
		$(MAKE) -C littlefs-c89 sizes-diff)

## download tools
.PHONY: tools
tools:
	# download wasi-sdk
	wget $(WASI_SDK_URL) -O wasi-sdk.tar.gz
	tar xvf wasi-sdk.tar.gz --transform 's/^wasi-sdk-[^\/]*/wasi-sdk/'
	# download wabt
	wget $(WABT_URL) -O wabt.tar.gz
	tar xvf wabt.tar.gz --transform 's/^wabt-[^\/]*/wabt/'

## show this help text
.PHONY: help
help:
	@$(strip awk '/^## / { \
	        sub(/^## /,""); \
	        getline rule; \
	        while (rule ~ /^(#|\.PHONY|ifdef|ifndef)/) getline rule; \
	        gsub(/:.*/, "", rule); \
	        printf " "" %-25s %s\n", rule, $$0 \
	    }' $(MAKEFILE_LIST))

## clean things
.PHONY: clean
clean:
	$(MAKE) -C littlefs clean
	rm -rf littlefs-c89
