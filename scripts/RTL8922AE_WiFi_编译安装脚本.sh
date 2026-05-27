#!/usr/bin/env bash
set -euo pipefail

# RTL8922AE / Realtek 10ec:8922 WiFi driver build script
# Tested on Ubuntu 22.04.5 LTS, kernel 6.8.0-40-generic.
# Run with:
#   bash RTL8922AE_WiFi_编译安装脚本.sh

if [ "${EUID}" -ne 0 ]; then
  exec sudo bash "$0" "$@"
fi

TARGET_USER="${SUDO_USER:-ubuntu}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
WORKSPACE="${TARGET_HOME}/workspace"
SRC_PARENT="${TARGET_HOME}/src/rtw89-main-unpacked"
SRC_DIR="${SRC_PARENT}/rtw89-main"
ZIP_FILE="${WORKSPACE}/rtw89-main.zip"
LOG_FILE="${WORKSPACE}/wifi-rtw89-build-$(date +%Y%m%d-%H%M%S).log"
URL="https://github.com/morrownr/rtw89/archive/refs/heads/main.zip"

mkdir -p "$WORKSPACE" "$SRC_PARENT"
exec > >(tee -a "$LOG_FILE") 2>&1

step() {
  echo
  echo "========== $* =========="
}

step "1. 基础信息"
echo "日志: $LOG_FILE"
echo "用户: $TARGET_USER"
echo "系统: $(lsb_release -ds 2>/dev/null || true)"
echo "内核: $(uname -r)"
lspci -nnk | grep -A8 -Ei 'network|wireless|wifi|802.11' || true

step "2. 清理失败的旧 rtw89 DKMS 条目"
dkms remove rtw89/7.1 --all || true
dpkg --configure -a || true
apt-get install -f -y || true

step "3. 安装编译依赖"
apt-get update
apt-get install -y \
  iw dkms mokutil build-essential "linux-headers-$(uname -r)" \
  unzip git curl

step "4. 恢复系统内核模块包，防止以前 cleanup 删除模块"
apt-get install --reinstall -y \
  "linux-modules-$(uname -r)" \
  "linux-modules-extra-$(uname -r)" || true
depmod -a

step "5. 准备 rtw89 源码包"
if [ ! -s "$ZIP_FILE" ]; then
  echo "未发现 $ZIP_FILE，尝试从 GitHub 下载。"
  curl -L --retry 5 --connect-timeout 20 -o "${ZIP_FILE}.tmp" "$URL"
  mv "${ZIP_FILE}.tmp" "$ZIP_FILE"
fi

if [ ! -s "$ZIP_FILE" ]; then
  echo "没有可用的源码包：$ZIP_FILE"
  echo "如果服务器无法访问 GitHub，请在本地下载 main.zip 后 scp 到该路径。"
  exit 20
fi

rm -rf "$SRC_DIR"
unzip -q -o "$ZIP_FILE" -d "$SRC_PARENT"
cd "$SRC_DIR"
echo "源码目录: $PWD"
grep -R "8922" -n . | head -40 || true

step "6. 给 Ubuntu 22.04 HWE 6.8 打兼容补丁"
cp -av core.c core.c.bak-ubuntu68 2>/dev/null || true
cp -av phy.c phy.c.bak-ubuntu68 2>/dev/null || true
cp -av usb.c usb.c.bak-ubuntu68 2>/dev/null || true

# Ubuntu 22.04 HWE 6.8 headers do not expose these newer mac80211 helpers.
sed -i 's/ieee80211_iterate_stations_mtx/ieee80211_iterate_stations_atomic/g' core.c phy.c
sed -i 's/ieee80211_purge_tx_queue(rtwdev->hw, &rtwusb->tx_queue\[i\]);/skb_queue_purge(\&rtwusb->tx_queue[i]);/g' usb.c

grep -R "ieee80211_iterate_stations_mtx\|ieee80211_purge_tx_queue" -n core.c phy.c usb.c || true

step "7. 手动编译，先确认源码能过"
make clean || true
make -j"$(nproc)" KVER="$(uname -r)" modules

step "8. DKMS 安装"
dkms remove rtw89/7.1 --all || true
dkms install "$PWD"

step "9. 安装固件和模块参数"
make install_fw || true
[ -f rtw89.conf ] && cp -v rtw89.conf /etc/modprobe.d/ || true

cat >/etc/modprobe.d/blacklist-rtw89-stock.conf <<'EOF'
# Avoid stock rtw89 modules taking Realtek 8922 before the DKMS git driver.
blacklist rtw_8922ae
blacklist rtw_8922a
blacklist rtw89pci
blacklist rtw89core
EOF

depmod -a
update-initramfs -u || true

step "10. 卸载旧模块并加载新驱动"
systemctl stop NetworkManager || true
for m in \
  rtw89_8922ae_git rtw89_8922a_git rtw89_pci_git rtw89_core_git \
  rtw_8922ae rtw_8922a rtw89pci rtw89core rtw89_pci rtw89_core; do
  modprobe -rv "$m" 2>/dev/null || rmmod "$m" 2>/dev/null || true
done

modprobe -v rtw89_8922ae_git
sleep 8
systemctl start NetworkManager || true
sleep 5

step "11. 验证"
dkms status || true
lsmod | grep -Ei 'rtw|mac80211|cfg80211' || true
lspci -nnk | grep -A8 -Ei 'network|wireless|wifi|802.11' || true
ip -br link || true
rfkill list all || true
nmcli radio all || true
nmcli device status || true
iw dev || true
dmesg -T | grep -Ei '07:00|8922|rtw89|rtw_8922|firmware|wlan|wireless|duplicate|Exec format|cfg80211' | tail -220 || true

step "12. 扫描 WiFi"
nmcli radio wifi on || true
nmcli device wifi rescan || true
sleep 5
nmcli device wifi list || true

step "完成"
echo "成功标志："
echo "1. lspci 显示 Kernel driver in use: rtw89_8922ae_git"
echo "2. ip -br link 显示 wlp7s0 或 wlan0"
echo "3. nmcli device wifi list 能扫描到 WiFi 名称"
echo "日志: $LOG_FILE"
