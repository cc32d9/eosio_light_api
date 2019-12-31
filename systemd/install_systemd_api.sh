SVC="lightapi_api.service"

for f in $SVC; do
    cp $f /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable $f
    systemctl start $f
done

