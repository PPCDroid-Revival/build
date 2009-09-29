# Copyright 2007 The Android Open Source Project
#
# Copies files into the directory structure described by a manifest

LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)

LOCAL_SRC_FILES := \
	kcm.cpp

ifeq ($(TARGET_ARCH),ppc)
LOCAL_CFLAGS += -DTARGET_BIG_ENDIAN
else
LOCAL_CFLAGS += -DTARGET_LITTLE_ENDIAN
endif

LOCAL_MODULE := kcm

include $(BUILD_HOST_EXECUTABLE)


