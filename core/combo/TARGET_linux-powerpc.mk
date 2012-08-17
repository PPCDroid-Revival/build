ifeq ($(strip $(TARGET_ARCH_VARIANT)),)
TARGET_ARCH_VARIANT := ppc603e
endif

TARGET_ARCH_SPECIFIC_MAKEFILE := $(BUILD_COMBOS)/arch/$(TARGET_ARCH)/$(TARGET_ARCH_VARIANT).mk
ifeq ($(strip $(wildcard $(TARGET_ARCH_SPECIFIC_MAKEFILE))),)
$(error Unknown PowerPC architecture version: $(TARGET_ARCH_VARIANT))
endif

include $(TARGET_ARCH_SPECIFIC_MAKEFILE)

ARCH_HAVE_BIGENDIAN := true

# You can set TARGET_TOOLS_PREFIX to get gcc from somewhere else
ifeq ($(strip $(TARGET_TOOLS_PREFIX)),)
TARGET_TOOLS_PREFIX := \
	prebuilt/$(HOST_PREBUILT_TAG)/toolchain/powerpc-android-linux-4.4.3/bin/powerpc-android-linux-
endif

# Only define these if there's actually a gcc in there.
# The gcc toolchain does not exists for windows/cygwin. In this case, do not reference it.
TARGET_CC := $(TARGET_TOOLS_PREFIX)gcc$(HOST_EXECUTABLE_SUFFIX)
TARGET_CXX := $(TARGET_TOOLS_PREFIX)g++$(HOST_EXECUTABLE_SUFFIX)
TARGET_AR := $(TARGET_TOOLS_PREFIX)ar$(HOST_EXECUTABLE_SUFFIX)
TARGET_OBJCOPY := $(TARGET_TOOLS_PREFIX)objcopy$(HOST_EXECUTABLE_SUFFIX)
TARGET_LD := $(TARGET_TOOLS_PREFIX)ld$(HOST_EXECUTABLE_SUFFIX)
TARGET_STRIP := $(TARGET_TOOLS_PREFIX)strip$(HOST_EXECUTABLE_SUFFIX)
TARGET_STRIP_COMMAND = $(TARGET_STRIP) --strip-debug $< -o $@

TARGET_NO_UNDEFINED_LDFLAGS := -Wl,--no-undefined -Wl,--bss-plt

TARGET_GLOBAL_CFLAGS += \
			-O2 \
			-mregnames \
			-fomit-frame-pointer\
			-fstrict-aliasing \
			-funswitch-loops


android_config_h := $(call select-android-config-h,linux-ppc)
arch_include_dir := $(dir $(android_config_h))



TARGET_GLOBAL_CFLAGS += \
			-fPIC -DPIC \
			-ffunction-sections \
			-fdata-sections \
			-funwind-tables \
			-Wa,--noexecstack \
			-Werror=format-security \
			-fno-short-enums \
			$(arch_variant_cflags) \
			-include $(android_config_h) \
			-I $(arch_include_dir)

# This warning causes dalvik not to build with gcc 4.6 and -Werror.
# We cannot turn it off blindly since the option is not available
# in gcc-4.4.x
ifneq ($(filter 4.6.0%, $(shell $(TARGET_CC) --version)),)
TARGET_GLOBAL_CFLAGS += -Wno-unused-but-set-variable
endif

# This is to avoid the dreaded warning compiler message:
#   note: the mangling of 'va_list' has changed in GCC 4.4
#
# The fact that the mangling changed does not affect the NDK ABI
# very fortunately (since none of the exposed APIs used va_list
# in their exported C++ functions). Also, GCC 4.5 has already
# removed the warning from the compiler.
#
#TARGET_GLOBAL_CFLAGS += -Wno-psabi

#			-Wl,--icf=safe
#			-Wl,--gc-sections
TARGET_GLOBAL_LDFLAGS += \
			-Wl,-z,noexecstack \
			$(arch_variant_ldflags)

TARGET_GLOBAL_CPPFLAGS += -fvisibility-inlines-hidden

TARGET_GLOBAL_CFLAGS += -mbionic
#TARGET_GLOBAL_CFLAGS += -D__ANDROID__

# More flags/options can be added here
TARGET_RELEASE_CFLAGS := \
			-g \


OTHER_RELEASE := \
			-DNDEBUG \
			-Wstrict-aliasing=2 \
			-fgcse-after-reload \
			-frerun-cse-after-loop \
			-frename-registers

libc_root := bionic/libc
libm_root := bionic/libm
libstdc++_root := bionic/libstdc++
libthread_db_root := bionic/libthread_db


## on some hosts, the target cross-compiler is not available so do not run this command
ifneq ($(wildcard $(TARGET_CC)),)
# We compile with the global cflags to ensure that
# any flags which affect libgcc are correctly taken
# into account.
TARGET_LIBGCC := $(shell $(TARGET_CC) $(TARGET_GLOBAL_CFLAGS) -print-libgcc-file-name)
endif

# Define FDO (Feedback Directed Optimization) options.

TARGET_FDO_CFLAGS:=
TARGET_FDO_LIB:=

target_libgcov := $(shell $(TARGET_CC) $(TARGET_GLOBAL_CFLAGS) \
        --print-file-name=libgcov.a)
ifneq ($(strip $(BUILD_FDO_INSTRUMENT)),)
  # Set BUILD_FDO_INSTRUMENT=true to turn on FDO instrumentation.
  # The profile will be generated on /data/local/tmp/profile on the device.
  TARGET_FDO_CFLAGS := -fprofile-generate=/data/local/tmp/profile -DANDROID_FDO
  TARGET_FDO_LIB := $(target_libgcov)
else
  # If BUILD_FDO_INSTRUMENT is turned off, then consider doing the FDO optimizations.
  # Set TARGET_FDO_PROFILE_PATH to set a custom profile directory for your build.
  ifeq ($(strip $(TARGET_FDO_PROFILE_PATH)),)
    TARGET_FDO_PROFILE_PATH := fdo/profiles/$(TARGET_ARCH)/$(TARGET_ARCH_VARIANT)
  else
    ifeq ($(strip $(wildcard $(TARGET_FDO_PROFILE_PATH))),)
      $(warning Custom TARGET_FDO_PROFILE_PATH supplied, but directory does not exist. Turn off FDO.)
    endif
  endif

  # If the FDO profile directory can't be found, then FDO is off.
  ifneq ($(strip $(wildcard $(TARGET_FDO_PROFILE_PATH))),)
    TARGET_FDO_CFLAGS := -fprofile-use=$(TARGET_FDO_PROFILE_PATH) -DANDROID_FDO
    TARGET_FDO_LIB := $(target_libgcov)
  endif
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

TARGET_C_INCLUDES := \
	$(libc_root)/arch-$(TARGET_ARCH)/include \
	$(libc_root)/include \
	$(libstdc++_root)/include \
	$(KERNEL_HEADERS) \
	$(libm_root)/include \
	$(libm_root)/include/$(TARGET_ARCH) \
	$(libthread_db_root)/include

TARGET_CRTBEGIN_STATIC_O := $(TARGET_OUT_STATIC_LIBRARIES)/crtbegin_static.o
TARGET_CRTBEGIN_DYNAMIC_O := $(TARGET_OUT_STATIC_LIBRARIES)/crtbegin_dynamic.o
TARGET_CRTEND_O := $(TARGET_OUT_STATIC_LIBRARIES)/crtend_android.o

TARGET_CRTBEGIN_SO_O := $(TARGET_OUT_STATIC_LIBRARIES)/crtbegin_so.o
TARGET_CRTEND_SO_O := $(TARGET_OUT_STATIC_LIBRARIES)/crtend_so.o

TARGET_STRIP_MODULE:=true

TARGET_DEFAULT_SYSTEM_SHARED_LIBRARIES := libc libstdc++ libm

TARGET_CUSTOM_LD_COMMAND := true

# Disable the Dalvik JIT compiler if not already specified.
ifeq ($(strip $(WITH_JIT)),)
    WITH_JIT := false
endif

define transform-o-to-shared-lib-inner
$(TARGET_CXX) \
	-nostdlib -Wl,-soname,$(notdir $@) \
	-Wl,--gc-sections \
	-Wl,-shared,-Bsymbolic \
	$(PRIVATE_TARGET_GLOBAL_LD_DIRS) \
	$(PRIVATE_TARGET_CRTBEGIN_SO_O) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--whole-archive \
	$(call normalize-target-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--no-whole-archive \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	-o $@ \
	$(PRIVATE_TARGET_GLOBAL_LDFLAGS) \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_TARGET_FDO_LIB) \
	$(PRIVATE_TARGET_LIBGCC) \
	$(PRIVATE_TARGET_CRTEND_SO_O)
endef

define transform-o-to-executable-inner
$(TARGET_CXX) -nostdlib -Bdynamic \
	-Wl,-dynamic-linker,/system/bin/linker \
	-Wl,--gc-sections \
	-Wl,-z,nocopyreloc \
	-o $@ \
	$(TARGET_GLOBAL_LD_DIRS) \
	-Wl,-rpath-link=$(TARGET_OUT_INTERMEDIATE_LIBRARIES) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	$(TARGET_CRTBEGIN_DYNAMIC_O) \
	$(PRIVATE_ALL_OBJECTS) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(TARGET_GLOBAL_LDFLAGS) \
	$(PRIVATE_LDFLAGS) \
	$(TARGET_FDO_LIB) \
	$(TARGET_LIBGCC) \
	$(TARGET_CRTEND_O)
endef

define transform-o-to-static-executable-inner
$(TARGET_CXX) -nostdlib -Bstatic \
	-Wl,--gc-sections \
	-o $@ \
	$(TARGET_GLOBAL_LD_DIRS) \
	$(TARGET_CRTBEGIN_STATIC_O) \
	$(TARGET_GLOBAL_LDFLAGS) \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--start-group \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(TARGET_FDO_LIB) \
	$(TARGET_LIBGCC) \
	-Wl,--end-group \
	$(TARGET_CRTEND_O)
endef
