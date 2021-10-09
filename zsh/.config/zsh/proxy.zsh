if [ -n "${use_proxy}" ] && [[ "${use_proxy}" == "true" ]];then
    function is_access_google()
    {
        return 1
    }
    return
fi

# 使用 curl 来测试原本的客户端能否访问 google
# --connect-timeout: 设置访问超时时间，如果不设置的话访问不了 google 会网络堵塞
# -I: 只显示 head
# -s: silent mode, 抑制错误信息输出
if [[ -n "`curl --connect-timeout 0.1 -Is google.com`" ]]; then
    # echo "can get forigin website"
    access_google=true
else
    # echo "can't get forigin website"
    access_google=false
fi

function is_access_google()
{
    [[ "$access_google" == "true" ]]
}
