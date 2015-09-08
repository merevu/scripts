#!/bin/bash


#----------------------
# setup packages
#----------------------
#yum update -y
yum install -y yum-plugin-priorities
yum install -y http://repos.fedorapeople.org/repos/openstack/EOL/openstack-icehouse/rdo-release-icehouse-3.noarch.rpm
sed -i "s/baseurl/#baseurl/" /etc/yum.repos.d/rdo-release.repo
echo "baseurl=http://repos.fedorapeople.org/repos/openstack/EOL/openstack-icehouse/epel-6/" >> /etc/yum.repos.d/rdo-release.repo
yum install -y http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum install -y openstack-utils
yum install -y openstack-swift
yum install -y openstack-swift-proxy memcached python-swiftclient python-keystone
yum install -y openstack-swift-account openstack-swift-container openstack-swift-object xfsprogs xinetd
yum install -y git


#----------------------
# setup config
#----------------------
rm -rf /etc/swift/*
cd $HOME && git clone https://github.com/openstack/swift.git
cd $HOME/swift && git checkout 2.0.0
cd $HOME/swift/doc/saio/swift/
tar cvf - . | tar xvf - -C /etc/swift
rm -rf /etc/swift/container-reconciler.conf
cd /etc/swift && sed -i "s/<your-user-name>/swift/" *conf */*conf
mkdir -p /var/log/swift


#----------------------
# make ring
#----------------------
$HOME/swift/doc/saio/bin/remakerings
chown -R swift:swift /etc/swift


#----------------------
# setup device
#----------------------
mkdir /srv
truncate -s 1GB /srv/swift-disk
mkfs.xfs /srv/swift-disk
echo "/dev/sdb1 /mnt/sdb1 xfs noatime,nodiratime,nobarrier,logbufs=8 0 0" >> /etc/fstab

export USER=swift
mkdir /mnt/sdb1
mount /mnt/sdb1
mkdir /mnt/sdb1/1 /mnt/sdb1/2 /mnt/sdb1/3 /mnt/sdb1/4
chown ${USER}:${USER} /mnt/sdb1/*
for x in {1..4}; do ln -s /mnt/sdb1/$x /srv/$x; done
mkdir -p /srv/1/node/sdb1 /srv/1/node/sdb5               /srv/2/node/sdb2 /srv/2/node/sdb6               /srv/3/node/sdb3 /srv/3/node/sdb7               /srv/4/node/sdb4 /srv/4/node/sdb8               /var/run/swift
chown -R ${USER}:${USER} /var/run/swift
for x in {1..4}; do chown -R ${USER}:${USER} /srv/$x/; done

mkdir -p /var/cache/swift /var/cache/swift2 /var/cache/swift3 /var/cache/swift4
chown swift:swift /var/cache/swift*
mkdir -p /var/run/swift
chown swift:swift /var/run/swift


#---------------------------
# setup config (non-swift)
#---------------------------
cp -n $HOME/swift/doc/saio/rsyncd.conf /etc/
sed -i "s/<your-user-name>/${USER}/" /etc/rsyncd.conf
sed -i "s/disable = yes/disable = no/" /etc/xinetd.d/rsync
service xinetd restart

cp -n $HOME/swift/doc/saio/rsyslog.d/10-swift.conf /etc/rsyslog.d/
service rsyslog restart

service memcached start
chkconfig memcached on


#---------------------------
# start service & test
#---------------------------
swift-init all restart

cd $HOME
cat > .swiftrc <<EOF
export ST_AUTH=localhost:8080/auth/v1.0
export ST_USER=test:tester
export ST_KEY=testing
EOF

swift stat
