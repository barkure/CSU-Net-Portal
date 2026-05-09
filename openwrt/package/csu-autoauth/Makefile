#
# Copyright (C) 2026
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=csu-autoauth
PKG_VERSION:=1.0.3
PKG_RELEASE:=1

PKG_SOURCE:=CSU-Net-Portal-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/barkure/CSU-Net-Portal/tar.gz/refs/tags/v$(PKG_VERSION)?
PKG_HASH:=baad9ddbf9f0d59db1bddcb240e09bcffdf2e13c256deec13f97d37a4b371bb1
PKG_BUILD_DIR:=$(BUILD_DIR)/CSU-Net-Portal-$(PKG_VERSION)

PKG_LICENSE:=MIT
PKG_ARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/csu-autoauth
  SECTION:=net
  CATEGORY:=Network
  TITLE:=CSU portal auto authentication service
  DEPENDS:=+curl
  URL:=https://github.com/barkure/CSU-Net-Portal
endef

define Package/csu-autoauth/description
  Auto authenticate to the Central South University network portal
  and keep the session alive.
endef

define Build/Compile
endef

define Package/csu-autoauth/conffiles
/etc/config/csu-autoauth
endef

define Package/csu-autoauth/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/openwrt/package/csu-autoauth/files/csu-autoauth.sh $(1)/usr/bin/csu-autoauth.sh
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/csu-autoauth.init $(1)/etc/init.d/csu-autoauth
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/csu-autoauth.config $(1)/etc/config/csu-autoauth
endef

$(eval $(call BuildPackage,csu-autoauth))
