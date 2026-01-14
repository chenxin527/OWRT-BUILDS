#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	echo " "

	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

#修改aurora主题配置
if [ -d *"luci-theme-aurora"* ]; then
	echo " "

	cd ./luci-theme-aurora/

	sed -i "/main.mediaurlbase/d" ./root/etc/uci-defaults/30_luci-theme-aurora

	cd $PKG_PATH && echo "theme-aurora has been fixed!"
fi

#修改bootstrap主题配置
BOOTSTRAP_THEME_DIR=../feeds/luci/themes/luci-theme-bootstrap
if [ -d "$BOOTSTRAP_THEME_DIR"* ]; then
	echo " "

	sed -i '/if \[ "\$PKG_UPGRADE" != 1 \] && \[ \$changed = 1 \]; then/,/fi/d' $BOOTSTRAP_THEME_DIR/root/etc/uci-defaults/30_luci-theme-bootstrap

	cd $PKG_PATH && echo "theme-bootstrap has been fixed!"
fi

#修改qca-nss-drv启动顺序
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
	echo " "

	sed -i 's/START=.*/START=85/g' $NSS_DRV

	cd $PKG_PATH && echo "qca-nss-drv has been fixed!"
fi

#修改qca-nss-pbuf启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
	echo " "

	sed -i 's/START=.*/START=86/g' $NSS_PBUF

	cd $PKG_PATH && echo "qca-nss-pbuf has been fixed!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust has been fixed!"
fi

#修复DiskMan编译失败
DM_FILE="./luci-app-diskman/applications/luci-app-diskman/Makefile"
if [ -f "$DM_FILE" ]; then
	echo " "

	sed -i '/ntfs-3g-utils /d' $DM_FILE

	cd $PKG_PATH && echo "diskman has been fixed!"
fi

#配置OpenClash
if [ -d *"openclash"* ]; then
	echo " "

	#修改默认配置
	OPENCLASH_CONFIG_FILE=$PKG_PATH/luci-app-openclash/root/etc/config/openclash
	if [ -f "$OPENCLASH_CONFIG_FILE" ]; then
		sed -i "s/ipv6_dns '.*'/ipv6_dns '1'/; s/enable_custom_clash_rules '.*'/enable_custom_clash_rules '1'/; s/append_wan_dns '.*'/append_wan_dns '1'/; s/append_default_dns '.*'/append_default_dns '1'/" $OPENCLASH_CONFIG_FILE
		echo "OpenClash config has been changed!"
	fi

	#添加自定义规则
	OPENCLASH_CUSTOM_RULES_FILE=$PKG_PATH/luci-app-openclash/root/etc/openclash/custom/openclash_custom_rules.list
	if [ -f "$OPENCLASH_CUSTOM_RULES_FILE" ]; then
		{
			echo -e "\n"
			echo "##我的规则"
			echo "- DOMAIN-KEYWORD,microsoft,DIRECT"
			echo "- DOMAIN-SUFFIX,bing.com,DIRECT"
			echo "- DOMAIN-SUFFIX,cudy.com,DIRECT"
			echo "- DOMAIN-SUFFIX,immortalwrt.org,DIRECT"
			echo "- DOMAIN-SUFFIX,msftconnecttest.com,DIRECT"
			echo "- DOMAIN-SUFFIX,pc521.net,DIRECT"
			echo "- DOMAIN-SUFFIX,pc528.net,DIRECT"
			echo "- DOMAIN-SUFFIX,xn--ngstr-lra8j.com,DIRECT"
			echo "- DST-PORT,22,DIRECT"
		} >> $OPENCLASH_CUSTOM_RULES_FILE
		echo "OpenClash custom rules have been added!"
	fi

	#集成Clash Meta内核
	CLASH_CORE_DIR=$PKG_PATH/luci-app-openclash/root/etc/openclash/core
	curl -sL -m 30 --retry 2 https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-"$CPU_MODEL".tar.gz -o /tmp/clash.tar.gz
	tar zxvf /tmp/clash.tar.gz -C /tmp >/dev/null 2>&1
	chmod +x /tmp/clash >/dev/null 2>&1
	mkdir -p $CLASH_CORE_DIR
	mv /tmp/clash $CLASH_CORE_DIR/clash_meta >/dev/null 2>&1
	rm -rf /tmp/clash.tar.gz >/dev/null 2>&1
	if [ -x "$CLASH_CORE_DIR/clash_meta" ]; then
		echo "OpenClash core has been installed!"
	else
		echo "OpenClash core installation failed!"
	fi

	cd $PKG_PATH
fi

#修复luci-app-netspeedtest相关问题
if [ -d *"luci-app-netspeedtest"* ]; then
	echo " "

	cd ./luci-app-netspeedtest/

	sed -i '$a\exit 0' ./netspeedtest/files/99_netspeedtest.defaults
	sed -i 's/ca-certificates/ca-bundle/g' ./speedtest-cli/Makefile

	cd $PKG_PATH && echo "netspeedtest has been fixed!"
fi
