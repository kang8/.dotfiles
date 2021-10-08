# 使用 curl 来测试原本的客户端能否访问 google
# --connect-timeout: 设置访问超时时间，如果不设置的话访问不了 google 会网络堵塞
# -I: 只显示 head
# -s: silent mode, 抑制错误信息输出
if [[ -n "`curl --connect-timeout 0.1 -Is google.com`" ]]; then
    echo "can get forigin website"
else
    echo "can't get forigin website"
fi
