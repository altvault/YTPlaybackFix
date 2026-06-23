THEOS_DEVICE_IP = localhost
THEOS_DEVICE_PORT = 2222
TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YTPlaybackFix

YTPlaybackFix_FILES = Tweak.x
YTPlaybackFix_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
