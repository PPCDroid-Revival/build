# Configuration for Linux on MIPS little endian.
# Included by combo/select.make

# You can set TARGET_ARCH_VERSION to use an arch version other
# than mips32
ifeq ($(strip $(TARGET_ARCH_VERSION)),)
TARGET_ARCH_VERSION := mips32
endif

# This set of if blocks sets makefile variables similar to preprocesser
# defines in system/core/include/arch/<combo>/AndroidConfig.h. Their
# purpose is to allow module Android.mk files to selctively compile
# different versions of code based upon the funtionality and 
# instructions available in a given architecture version.
#
# The blocks also define specific arch_version_cflags, which 
# include defines, and compiler settings for the given architecture
# version.
#
# Note: Hard coding the 'tune' value here is probably not ideal,
# and a better solution should be found in the future.
#
# With two or three different versions this if block approach is
# fine. If/when this becomes large, please change this to include
# architecture versions specific Makefiles which define these
# variables.

MIPS_ENDIAN := -EL
ifeq ($(TARGET_ARCH_VERSION),mips32)
arch_version_cflags := -march=mips32 -msoft-float $(MIPS_ENDIAN)
else
$(error Unknown MIPS architecture version: $(TARGET_ARCH_VERSION))
endif

# You can set TARGET_TOOLS_PREFIX to get gcc from somewhere else
ifeq ($(strip $($(combo_target)TOOLS_PREFIX)),)
$(combo_target)TOOLS_PREFIX := \
	prebuilt/$(HOST_PREBUILT_TAG)/toolchain/mipsel-linux-4.2.4/bin/mipsel-android-linux-
endif

$(combo_target)CC := $($(combo_target)TOOLS_PREFIX)gcc$(HOST_EXECUTABLE_SUFFIX)
$(combo_target)CXX := $($(combo_target)TOOLS_PREFIX)g++$(HOST_EXECUTABLE_SUFFIX)
$(combo_target)AR := $($(combo_target)TOOLS_PREFIX)ar$(HOST_EXECUTABLE_SUFFIX)
$(combo_target)OBJCOPY := $($(combo_target)TOOLS_PREFIX)objcopy$(HOST_EXECUTABLE_SUFFIX)
$(combo_target)LD := $($(combo_target)TOOLS_PREFIX)ld$(HOST_EXECUTABLE_SUFFIX)

$(combo_target)NO_UNDEFINED_LDFLAGS := -Wl,--no-undefined

$(combo_target)GLOBAL_CFLAGS += \
			-O2 \
			-fomit-frame-pointer\
			-fstrict-aliasing \
			-funswitch-loops \
			-fPIC \
			-ffunction-sections \
			-funwind-tables \
			-fno-short-enums \
			$(arch_version_cflags) \
			-include $(call select-android-config-h,linux-mips)

$(combo_target)GLOBAL_CPPFLAGS += \
			-fvisibility-inlines-hidden \
			-fno-use-cxa-atexit

$(combo_target)RELEASE_CFLAGS := \
			-DSK_RELEASE -DNDEBUG \
			-g \
			-Wstrict-aliasing=2 \
			-finline-functions \
			-fno-inline-functions-called-once \
			-fgcse-after-reload \
			-frerun-cse-after-loop \
			-frename-registers

libc_root := bionic/libc
libm_root := bionic/libm
libstdc++_root := bionic/libstdc++
libthread_db_root := bionic/libthread_db

ifneq ($(wildcard $($(combo_target)CC)),)
# We compile with the global cflags to ensure that 
# any flags which affect libgcc are correctly taken
# into account.
$(combo_target)LIBGCC := $(shell $($(combo_target)CC) $($(combo_target)GLOBAL_CFLAGS) -print-libgcc-file-name)
endif

# unless CUSTOM_KERNEL_HEADERS is defined, we're going to use
# symlinks located in out/ to point to the appropriate kernel
# headers. see 'config/kernel_headers.make' for more details
#
ifneq ($(CUSTOM_KERNEL_HEADERS),)
    KERNEL_HEADERS_COMMON := $(CUSTOM_KERNEL_HEADERS)
    KERNEL_HEADERS_ARCH   := $(CUSTOM_KERNEL_HEADERS)
else
    KERNEL_HEADERS_COMMON := $(libc_root)/kernel/common
    KERNEL_HEADERS_ARCH   := $(libc_root)/kernel/arch-$(TARGET_ARCH)
endif
KERNEL_HEADERS := $(KERNEL_HEADERS_COMMON) $(KERNEL_HEADERS_ARCH)

$(combo_target)C_INCLUDES := \
	$(libc_root)/arch-mips/include \
	$(libc_root)/include \
	$(libstdc++_root)/include \
	$(KERNEL_HEADERS) \
	$(libm_root)/include \
	$(libm_root)/include/arch/mips \
	$(libthread_db_root)/include

TARGET_CRTBEGIN_STATIC_O := $(TARGET_OUT_STATIC_LIBRARIES)/crtbegin_static.o
TARGET_CRTBEGIN_DYNAMIC_O := $(TARGET_OUT_STATIC_LIBRARIES)/crtbegin_dynamic.o
TARGET_CRTEND_O := $(TARGET_OUT_STATIC_LIBRARIES)/crtend_android.o

TARGET_CRTBEGIN_SO_O := $(TARGET_OUT_STATIC_LIBRARIES)/crtbegin_so.o
TARGET_CRTEND_SO_O := $(TARGET_OUT_STATIC_LIBRARIES)/crtend_so.o

TARGET_STRIP_MODULE:=true

$(combo_target)DEFAULT_SYSTEM_SHARED_LIBRARIES := libc libstdc++ libm

$(combo_target)CUSTOM_LD_COMMAND := true
define transform-o-to-shared-lib-inner
$(TARGET_CXX) \
	-shared $(MIPS_ENDIAN) \
	-Wl,-shared,-Bsymbolic \
	-fPIC -nostdlib \
	$(TARGET_GLOBAL_LD_DIRS) \
	$(TARGET_CRTBEGIN_SO_O) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--whole-archive \
	$(call normalize-host-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--no-whole-archive \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	-Wl,-soname -Wl,$(notdir $@) \
	-o $@ \
	$(TARGET_CRTEND_SO_O) \
	$(PRIVATE_LDFLAGS) \
	$(TARGET_LIBGCC)
endef

define transform-o-to-executable-inner
$(TARGET_CXX) -nostdlib -Bdynamic \
	-Wl,-dynamic-linker,/system/bin/linker \
    -Wl,--gc-sections $(MIPS_ENDIAN) \
	-Wl,-z,nocopyreloc \
	-o $@ \
	$(TARGET_GLOBAL_LD_DIRS) \
	-Wl,-rpath-link=$(TARGET_OUT_INTERMEDIATE_LIBRARIES) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	$(TARGET_CRTBEGIN_DYNAMIC_O) \
	$(PRIVATE_ALL_OBJECTS) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(PRIVATE_LDFLAGS) \
	$(TARGET_LIBGCC) \
	$(TARGET_CRTEND_O)
endef

define transform-o-to-static-executable-inner
$(TARGET_CXX) -nostdlib -Bstatic \
    -Wl,--gc-sections $(MIPS_ENDIAN)\
	-o $@ \
	$(TARGET_GLOBAL_LD_DIRS) \
	$(TARGET_CRTBEGIN_STATIC_O) \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_ALL_OBJECTS) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(TARGET_LIBGCC) \
	$(TARGET_CRTEND_O)
endef

# We need to set these LOCAL variables, for now.
LOCAL_ARM_MODE := mips
DISABLE_DEXPREOPT := true
