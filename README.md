# Ubuntu GPU 工作站与 RTL8922AE WiFi 驱动安装资料

这个仓库整理了本次 Ubuntu 22.04 GPU 工作站环境安装验证资料，以及 ASUS PRIME X870-P WIFI 主板 Realtek RTL8922AE 无线网卡驱动的编译安装资料。


scripts/
  RTL8922AE_WiFi.sh

packages/
  rtw89-main.zip
```

## GPU 工作站环境

详细安装和验证教程见：

## RTL8922AE WiFi 驱动

详细教程见：

一键脚本：

```text
scripts/RTL8922AE_WiFi.sh
```

源码包：

```text
packages/rtw89-main.zip
```

## WiFi 驱动使用方法

把脚本和源码包上传到服务器：

```bash
#指定这个目录，不然脚本使用不了，会自己重新下载包
/home/ubuntu/workspace/
```

登录服务器并执行：

```bash
bash /home/ubuntu/workspace/RTL8922AE_WiFi.sh
```

成功标志：

```bash
dkms status
lspci -nnk | grep -A8 -Ei 'network|wireless|wifi|802.11'
ip -br link
nmcli device wifi list
```

应看到：

```text
rtw89/7.1 installed
Kernel driver in use: rtw89_8922ae_git
wlp7s0
能扫描到 WiFi 名称
```

## 注意

- WiFi 驱动脚本不升级系统，也不升级内核。
- 如果服务器无法访问 GitHub，可直接使用仓库里的 `packages/rtw89-main.zip`。
- 如果机器开启 Secure Boot，DKMS 模块签名可能需要额外处理 MOK enrollment。
