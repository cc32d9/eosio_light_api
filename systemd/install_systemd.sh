NETWORKS="eos"

for n in $NETWORKS; do
    if [ ! -r /etc/default/lightapi_${n} ]; then
        echo Cannot find environment file /etc/default/lightapi_${n} 1>&2
        exit 1
    fi
done

cp *.service /etc/systemd/system/

systemctl daemon-reload

for n in $NETWORKS; do
    systemctl enable lightapi_dbwrite@${n}.service
    systemctl start lightapi_dbwrite@${n}.service
done


for f in lightapi_api.service; do
    systemctl enable $f
    systemctl start $f
done

