PORTS="$@"

if [ x"$PORTS" = x ]; then 
	echo "Need port numbers as arguments" 1>&2
	exit 1;
fi


cp fio_lightapi_wsapi@.service /etc/systemd/system/
systemctl daemon-reload

for p in $PORTS; do
    systemctl enable fio_lightapi_wsapi@${p}
    systemctl start fio_lightapi_wsapi@${p}
done


