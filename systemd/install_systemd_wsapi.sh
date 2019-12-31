PORTS="$@"

if [ x"$PORTS" = x ]; then 
	echo "Need port numbers as arguments" 1>&2
	exit 1;
fi


cp lightapi_wsapi@.service /etc/systemd/system/
systemctl daemon-reload

for p in $PORTS; do
    systemctl enable lightapi_wsapi@${p}
    systemctl start lightapi_wsapi@${p}
done


