SVC="lightapi_api.service"

for f in $SVC; do
    cp lightapi_api.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable $f
    systemctl start $f
done

