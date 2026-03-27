include $(TOPDIR)/rules.mk

PKG_NAME:=csu-autoauth
PKG_VERSION:=1.0.2
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=barkure
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/csu-autoauth
  SECTION:=net
  CATEGORY:=Network
  TITLE:=CSU portal auto authentication service
  DEPENDS:=+curl
endef

define Package/csu-autoauth/description
  Auto authenticate to the Central South University network portal and keep the session alive.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/csu-autoauth/conffiles
/etc/config/csu-autoauth
endef

define Package/csu-autoauth/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/csu-autoauth.sh $(1)/usr/bin/csu-autoauth.sh
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/csu-autoauth.init $(1)/etc/init.d/csu-autoauth
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/csu-autoauth.config $(1)/etc/config/csu-autoauth
endef

define Package/csu-autoauth/postinst
#!/bin/sh
if [ -z "$$IPKG_INSTROOT" ]; then
	chmod +x /usr/bin/csu-autoauth.sh /etc/init.d/csu-autoauth
	/etc/init.d/csu-autoauth enable >/dev/null 2>&1 || true
	/etc/init.d/csu-autoauth restart >/dev/null 2>&1 || /etc/init.d/csu-autoauth start >/dev/null 2>&1 || true
fi
exit 0
endef

$(eval $(call BuildPackage,csu-autoauth))
