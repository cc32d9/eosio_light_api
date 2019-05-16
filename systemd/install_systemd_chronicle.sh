NETWORKS="$@"

if [ x"$NETWORKS" = x ]; then 
	echo "Need network names as arguments" 1>&2
	exit 1;
fi


cp chronicle_receiver\@.service /etc/systemd/system/

systemctl daemon-reload

for n in $NETWORKS; do
    systemctl enable chronicle_receiver@${n}.service
    systemctl start chronicle_receiver@${n}.service
    echo installed chronicle_receiver@${n}.service
done



