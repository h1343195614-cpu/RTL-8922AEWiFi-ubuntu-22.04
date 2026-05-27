RTL8922AE WiFi 驱动编译资料

文件说明：

1. RTL8922AE_WiFi驱动编译安装教程.pdf
   详细教程，包含问题判断、依赖包、源码下载、编译命令、坑点和验证命令。

2. RTL8922AE_WiFi_编译安装脚本.sh
   下次重装时可直接复制到服务器执行的脚本。

3. rtw89-main.zip
   本次使用的第三方 Realtek rtw89 驱动源码包。

服务器上执行方式：

scp RTL8922AE_WiFi_编译安装脚本.sh ubuntu@192.168.1.46:/home/ubuntu/workspace/
scp rtw89-main.zip ubuntu@192.168.1.46:/home/ubuntu/workspace/

ssh ubuntu@192.168.1.46
bash /home/ubuntu/workspace/RTL8922AE_WiFi_编译安装脚本.sh

成功标志：

lspci 显示 Kernel driver in use: rtw89_8922ae_git
ip -br link 显示 wlp7s0
nmcli device wifi list 能扫描到 WiFi 名称
