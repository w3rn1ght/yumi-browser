TARGET := iphone:clang:latest:12.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Yumi

Yumi_FILES = $(wildcard YumiBrowser/*.m)
Yumi_FRAMEWORKS = UIKit Foundation WebKit AVKit AVFoundation CoreMedia CoreGraphics
Yumi_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -IYumiBrowser
Yumi_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "killall -9 Yumi || true"
