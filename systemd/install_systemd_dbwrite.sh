NETWORKS="$@"

if [ x"$NETWORKS" = x ]; then 
	echo "Need network names as arguments" 1>&2
	exit 1;
fi

for n in $NETWORKS; do
    if [ ! -r /etc/default/fio_lightapi_${n} ]; then
        echo Cannot find environment file /etc/default/fio_lightapi_${n} 1>&2
        exit 1
    fi
done

cp fio_lightapi_dbwrite\@.service /etc/systemd/system/

systemctl daemon-reload

for n in $NETWORKS; do
    systemctl enable fio_lightapi_dbwrite@${n}.service
    systemctl start fio_lightapi_dbwrite@${n}.service
    echo installed fio_lightapi_dbwrite@${n}.service
done



