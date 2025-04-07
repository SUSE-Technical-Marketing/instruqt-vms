increase_limits() {
  echo "fs.inotify.max_user_instances=1024" >> /etc/sysctl.conf
  sysctl -p
  ulimit -n 65536
}
