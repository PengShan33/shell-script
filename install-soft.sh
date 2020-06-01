#!/bin/bash
#This script is only used to root

FILE=all.txt
HA_FILE=hadoop.txt
ZK_FILE=zookeeper.txt
HB_FILE=hbase.txt
KF_FILE=kafka.txt

USER=root
USER_PATH=/$USER
USER_INSTALL_PATH=$USER_PATH/install
USER_SOFT_PATH=$USER_PATH/software
PROFILE=$USER_PATH/.bash_profile

JDK_NAME="jdk-8u161-linux-x64.tar.gz"
JDK=jdk1.8.0_161

ZOOKEEPER_NAME="zookeeper-3.4.7.tar.gz"
ZOOKEEPER=zookeeper-3.4.7

HADOOP_NAME="hadoop-2.8.4.tar.gz"
HADOOP=hadoop-2.8.4

HBASE_NAME="hbase-2.2.4-bin.tar.gz"
HBASE=hbase-2.2.4

KAFKA_NAME="kafka_2.11-2.1.0.tgz"
KAFKA=kafka_2.11-2.1.0

ALL_IPS=($(awk -F : '{print $1}' $FILE))
ALL_PW=($(awk -F : '{print $3}' $FILE))
HADOOP_IPS=($(awk -F : '{print $1}' $HA_FILE))
ZK_IPS=($(awk -F : '{print $1}' $ZK_FILE))
HB_IPS=($(awk -F : '{print $1}' $HB_FILE))
KAFKA_IPS=($(awk -F : '{print $1}' $KF_FILE))

NN01=${HADOOP_IPS[0]}
NN02=${HADOOP_IPS[1]}

LOCAL_HOST=${ALL_IPS[0]}
LOCAL_HOST_PW=${ALL_PW[0]}


mkdir -p $USER_INSTALL_PATH
mkdir -p $USER_SOFT_PATH

#配置免密登录
function keygen(){
	echo "============开始配置免密登录============"
	for((i=0;i<${#ALL_IPS[@]};i++));
	do
		yum -y install expect
		if [ "${ALL_IPS[$i]}" = "${LOCAL_HOST}" ];then
			echo "创建${ALL_IPS[$i]}的密钥"
			rm -rf ${USER_PATH}/.ssh/*
			echo "请按3次回车键"
			ssh-keygen -t rsa
			cat ${USER_PATH}/.ssh/id_rsa.pub >> ${USER_PATH}/.ssh/authorized_keys
		else
			echo "创建${ALL_IPS[$i]}的密钥"
			/usr/bin/expect <<-EOF
			spawn ssh ${ALL_IPS[$i]}
			expect {
				"*yes/no)*" { send "yes\r"; exp_continue }
				"*assword:*" { send "${ALL_PW[$i]} \r" }
			}
			expect "*#" { send "yum -y install expect\r" }
			expect "*#" { send "rm -rf ${USER_PATH}/.ssh/*\r"}
			expect "*#" {send "ssh-keygen -t rsa\r" }
			expect "*rsa):" { send "\r"
				expect "*y/n)?" { send "y\r" }
				expect "*passphrase):" { send "\r"} 
				expect "*again:" { send "\r"}
			}
			expect "*#" {send "cat ${USER_PATH}/.ssh/id_rsa.pub >> ${USER_PATH}/.ssh/authorized_keys\r"}
			expect "*#" {send "scp ${USER_PATH}/.ssh/authorized_keys ${USER}@${LOCAL_HOST}:${USER_PATH}/.ssh/authorized_keys_${ALL_IPS[$i]}\r"
				 expect "*yes/no)?*" { send "yes\r"}
				 expect "*ssword:*" { send "${LOCAL_HOST_PW}\r" } 
			}
			expect "*#" {send "logout\r"}
			expect eof
			EOF
		fi	
	done
	
	cat ${USER_PATH}/.ssh/authorized_keys_* >> ${USER_PATH}/.ssh/authorized_keys
	

	for((i=0;i<${#ALL_IPS[@]};i++));
	do
		/usr/bin/expect <<-EOF
		spawn scp ${USER_PATH}/.ssh/authorized_keys ${USER}@${ALL_IPS[$i]}:${USER_PATH}/.ssh/
		expect {
			"*yes/no)?*" { send "yes\r" }
			"*ssword:*" { send "${ALL_PW[$i]}\r" }
		}
		expect eof
		EOF
	done
	
	echo ""
	if [ $? -eq 0 ];then
		echo "免密登录配置成功"
	else
		echo "免密登录配置失败"
		exit
	fi
}

#关闭并禁用当前操作系统的防火墙
#关闭防火墙不成功,还需要再测试#
function disableFireWalld(){
	for((i=0;i<${#ALL_IPS[@]};i++));
	do
		if [ "${ALL_IPS[$i]}" = "${LOCAL_HOST}" ];then
			echo "${ALL_IPS[$i]}当前系统的防火墙状态如下:"
			firewall-cmd --state
			echo "正在关闭防火墙..."
			systemctl stop firewall.server.service &> /dev/null
			systemctl disable firewall.service &> /dev/null
			echo "${ALL_IPS[$i]}当前系统的防火墙状态如下:"
			firewall-cmd --state
		else
			echo "创建${ALL_IPS[$i]}的密钥"
			/usr/bin/expect <<-EOF
			spawn ssh ${ALL_IPS[$i]}
			expect "*#" { send "echo ${ALL_IPS[$i]}当前系统的防火墙状态如下:\r" }
			expect "*#" { send "firewall-cmd --state\r"}
			expect "*#" { send "systemctl stop firewall.service &> /dev/null\r" }
			expect "*#" { send "systemctl disable firewall.service &> /dev/null\r"}
			expect "*#" { send "echo "${ALL_IPS[$i]}当前系统的防火墙状态如下:"\r" }
			expect "*#" { send "firewall-cmd --state\r"}
			expect "*#" { send "logout\r"}
			expect eof
			EOF
		fi	
		
		# ssh ${ALL_IPS[$i]}
		# echo "${ALL_IPS[$i]}当前系统的防火墙状态如下:"
		# firewall-cmd --state
		# echo "正在关闭防火墙..."
		# systemctl stop firewall &> /dev/null
		# systemctl disable firewall.service &> /dev/null
		# echo "${ALL_IPS[$i]}当前系统的防火墙状态如下:"
		# firewall-cmd --state
		# #试试
		# if [ ${ALL_IPS[$i]} -ne $LOCAL_HOST ];then
			# logout
		# fi
	done
}

#安装JDK
function install_JDK(){
	echo "============开始安装JDK============"
	
	mkdir -p $USER_INSTALL_PATH
	mkdir -p $USER_SOFT_PATH
	
	#解压JDK安装包
	cp ./$JDK_NAME $USER_INSTALL_PATH
	echo "正在解压java安装包,请稍等..."
	tar -zxvf $USER_INSTALL_PATH/$JDK_NAME -C $USER_SOFT_PATH
	mv $USER_SOFT_PATH/$JDK $USER_SOFT_PATH/java
	
	sleep 5
	echo "正在设置环境变量..."
	echo "export JAVA_HOME=$USER_SOFT_PATH/java" >> $PROFILE
	echo "export PATH=.:\$JAVA_HOME/bin:\$PATH" >> $PROFILE
	
	for IP in ${ALL_IPS[@]};
	do
		if [ "${IP}" = "${LOCAL_HOST}" ];then
			source $PROFILE
		else
			scp -r $USER_SOFT_PATH $USER@$IP:$USER_PATH/
			scp $PROFILE $USER@$IP:$USER_PATH/
		fi
	done
	
	for IP in ${ALL_IPS[@]};
	do
		if [ "${IP}" = "${LOCAL_HOST}" ];then
			source $PROFILE
			java -version
		else
			/usr/bin/expect <<-EOF
			spawn ssh ${IP}
			expect "*#" { send "source $PROFILE\r" }
			expect "*#" { send "java -version\r"}
			expect "*#" { send "logout\r"}
			expect eof
			EOF
		fi
	done
	
	# if [ $? -eq 0 ];then
		# echo "java安装成功"
	# else
		# echo "java安装失败"
	# fi
}

function install_Zookeeper(){
	echo "============开始安装zookeeper============"

	#解压zookeeper安装包
	cp ./$ZOOKEEPER_NAME $USER_INSTALL_PATH
	echo "正在解压zookeeper安装包,请稍等..."

	tar -zxvf $USER_INSTALL_PATH/$ZOOKEEPER_NAME -C $USER_SOFT_PATH
	mv $USER_SOFT_PATH/$ZOOKEEPER $USER_SOFT_PATH/zookeeper
	
	mkdir -p $USER_SOFT_PATH/zookeeper/data
	mkdir -p $USER_SOFT_PATH/zookeeper/log
	chmod -R 755 $USER_SOFT_PATH/zookeeper/data
	chmod -R 755 $USER_SOFT_PATH/zookeeper/log
	
	sleep 1
	echo "正在设置配置文件..."
	cp $USER_SOFT_PATH/zookeeper/conf/zoo_sample.cfg $USER_SOFT_PATH/zookeeper/conf/zoo.cfg
	zoo_cfg=$USER_SOFT_PATH/zookeeper/conf/zoo.cfg
	ZK_DATA=$USER_SOFT_PATH/zookeeper/data
	ZK_DATA_ZOO=$(echo $ZK_DATA |sed -e 's/\//\\\//g')
	sed -i "s/^dataDir=.*zookeeper$/dataDir=${ZK_DATA_ZOO}/g" $zoo_cfg
	echo "dataLogDir=$USER_SOFT_PATH/zookeeper/log" >> $zoo_cfg
	
	SERVER=""
	for((i=0;i<${#ZK_IPS[@]};i++));
	do
		echo "${SERVER}server.$[$i+1]=${ZK_IPS[$i]}:2888:3888" >> $zoo_cfg
	done

	touch $ZK_DATA/myid
	echo "1" > $ZK_DATA/myid
	
	sleep 1
	echo "正在设置环境变量..."
	echo "export ZK_HOME=$USER_SOFT_PATH/zookeeper" >> $PROFILE
	oldpath=`grep '^export PATH=.*' $PROFILE`
	sed -i "/export PATH=/c \\$oldpath:\$ZK_HOME/bin" $PROFILE
	
	#远程拷贝
	sleep 1
	echo "正在远程拷贝..."
	for IP in ${ZK_IPS[@]};
	do
		if [ "${IP}" = "${LOCAL_HOST}" ];then
			source $PROFILE
		else
			scp -r $USER_SOFT_PATH/zookeeper/ $USER@$IP:$USER_SOFT_PATH/
			scp $PROFILE $USER@$IP:$USER_PATH/
		fi 
	done
	
	for((i=0;i<${#ZK_IPS[@]};i++));
	do
		if [ "${ZK_IPS[$i]}" = "${LOCAL_HOST}" ];then
			echo "$[$i+1]" > $ZK_DATA/myid
			source $PROFILE
		else
			/usr/bin/expect <<-EOF
			spawn ssh ${ZK_IPS[$i]}
			expect "*#" { send "source $PROFILE\r" }
			expect "*#" { send "echo $[$i+1] > $ZK_DATA/myid\r"}
			expect "*#" { send "logout\r"}
			expect eof
			EOF
		fi
	done
	
	if [ $? -eq 0 ];then
		echo "zookeeper安装成功"
	else
		echo "zookeeper安装失败"
	fi
}
function start_Zookeeper(){
	echo "正在启动zookeeper..."
	for IP in ${ZK_IPS[@]};
	do
		if [ "${IP}" = "${LOCAL_HOST}" ];then
			source $PROFILE
			$USER_SOFT_PATH/zookeeper/bin/zkServer.sh start
			echo "$IP zookeeper状态如下:"
			$USER_SOFT_PATH/zookeeper/bin/zkServer.sh status
		else
			/usr/bin/expect <<-EOF
			spawn ssh ${IP}
			expect "*#" { send "source $PROFILE\r" }
			expect "*#" { send "$USER_SOFT_PATH/zookeeper/bin/zkServer.sh start\r"}
			expect "*#" { send "echo $IP zookeeper状态如下:\r"}
			expect "*#" { send "$USER_SOFT_PATH/zookeeper/bin/zkServer.sh status\r"}
			expect "*#" { send "logout\r"}
			expect eof
			EOF
		fi 
	done
}
function stop_Zookeeper(){
	echo "正在停止zookeeper..."
	for IP in ${ZK_IPS[@]};
	do
		if [ "${IP}" = "${LOCAL_HOST}" ];then
			zkServer.sh stop
			echo "$IP zookeeper状态如下:"
			zkServer.sh status
		else
			/usr/bin/expect <<-EOF
			spawn ssh ${IP}
			expect "*#" { send "$USER_SOFT_PATH/zookeeper/bin/zkServer.sh stop\r"}
			expect "*#" { send "echo $IP zookeeper状态如下:\r"}
			expect "*#" { send "$USER_SOFT_PATH/zookeeper/bin/zkServer.sh status\r"}
			expect "*#" { send "logout\r"}
			expect eof
			EOF
		fi 
	done
}

function install_Hadoop(){
	echo "============开始安装hadoop============"

	#准备slaves/JournalNode/2个NN
	SLAVES=""
	JournalNode=""
	for((i=0;i<${#HADOOP_IPS[@]};i++));
	do
		SLAVES="${SLAVES}${HADOOP_IPS[$i]}\n"
		JournalNode="$JournalNode${HADOOP_IPS[$i]}:8485;"
	done
	JournalNode=${JournalNode%;}
	JournalNode="qjournal://$JournalNode/hdfscluster"
	SLAVES=`echo ${SLAVES%'\n'}`
	
	#对zookeeper的ip和port进行拼接
	ZOOKEEPER_PORT=""	
	for((i=0;i<${#ZK_IPS[@]};i++));
	do
		ZOOKEEPER_PORT="${ZOOKEEPER_PORT}${ZK_IPS[$i]}:2181,"
	done
	ZOOKEEPER_PORT=`echo ${ZOOKEEPER_PORT%,}`  

	#解压hadoop安装包
	echo "正在解压hadoop安装包,请稍等..."
	cp ./$HADOOP_NAME $USER_INSTALL_PATH
	tar -zxvf $USER_INSTALL_PATH/$HADOOP_NAME -C $USER_SOFT_PATH
	mv $USER_SOFT_PATH/$HADOOP $USER_SOFT_PATH/hadoop

	cp $USER_SOFT_PATH/hadoop/etc/hadoop/mapred-site.xml.template $USER_SOFT_PATH/hadoop/etc/hadoop/mapred-site.xml
	hadoop_env="$USER_SOFT_PATH/hadoop/etc/hadoop/hadoop-env.sh"
	core_site="$USER_SOFT_PATH/hadoop/etc/hadoop/core-site.xml"
	hdfs_site="$USER_SOFT_PATH/hadoop/etc/hadoop/hdfs-site.xml"
	yarn_site="$USER_SOFT_PATH/hadoop/etc/hadoop/yarn-site.xml"
	mapred_site="$USER_SOFT_PATH/hadoop/etc/hadoop/mapred-site.xml"
	slaves="$USER_SOFT_PATH/hadoop/etc/hadoop/slaves"
	
	sleep 1
	echo "正在设置配置文件..."	
	#configure mapred-site.xml
	sed -i "/<configuration>/d" $mapred_site
	sed -i "/<\/configuration>/d" $mapred_site
	echo "
	<configuration>
		  <property>
			  <name>mapreduce.framework.name</name>
			  <value>yarn</value>
		  </property>
		</configuration>" >> $mapred_site

	#configure core-site.xml
	sed -i "/<configuration>/d" $core_site
	sed -i "/<\/configuration>/d" $core_site
	echo "
	<configuration>
		<property>
			<name>fs.defaultFS</name>
			<value>hdfs://hdfscluster</value>
		</property>
		<property>
			<name>hadoop.tmp.dir</name>
			<value>$USER_SOFT_PATH/hadoop/tmp</value>
		</property>
		<property>
			<name>fs.trash.interval</name>
			<value>1440</value>
		</property>
		<property>
			<name>ha.zookeeper.quorum</name>
			<value>$ZOOKEEPER_PORT</value>
		</property>
		<property>
			<name>ipc.client.connect.max.retries</name>
			<value>100</value>
			<description>Indicates the number of retries a client will make to establish a server connection.</description>
	    </property>
	    <property>
			<name>ipc.client.connect.retry.interval</name>
			<value>10000</value>
			<description>Indicates the number of milliseconds a client will wait for before retrying to establish a server connection.</description>
	   </property>
	</configuration>
	" >> $core_site

	#configure hdfs-site.xml
	sed -i "/<configuration>/d" $hdfs_site
	sed -i "/<\/configuration>/d" $hdfs_site
	echo "
	<configuration>
		<property>
			<name>dfs.nameservices</name>
			<value>hdfscluster</value>
		</property>

		<property>
			<name>dfs.ha.namenodes.hdfscluster</name>
			<value>nn1,nn2</value>
		</property>

		<property>
			<name>dfs.namenode.rpc-address.hdfscluster.nn1</name>
			<value>$NN01:8020</value>
			<description>nn1的RPC通信地址</description>
		</property>

		<property>
			<name>dfs.namenode.rpc-address.hdfscluster.nn2</name>
			<value>$NN02:8020</value>
			<description>nn2的RPC通信地址</description>
		</property>

		<property>
			<name>dfs.namenode.http-address.hdfscluster.nn1</name>
			<value>$NN01:50070</value>
			<description>nn1的http通信地址</description>
		</property>
		<property>
			<name>dfs.namenode.http-address.hdfscluster.nn2</name>
			<value>$NN02:50070</value>
			<description>nn2的http通信地址</description>
		</property>

		<property>
			<name>dfs.namenode.shared.edits.dir</name>
			<value>$JournalNode</value>
		</property>

		<property>
			<name>dfs.journalnode.edits.dir</name>
			<value>$USER_SOFT_PATH/hadoop/datas/journal</value>
			<description>新建目录，用于设置journalnode节点保存本地状态的目录,指定journalnode日志文件存储的路径</description>
		</property>

		<property>
			<name>dfs.client.failover.proxy.provider.hdfscluster</name>
			<value>org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider</value>
			<description>配置失败自动切换实现方式,指定HDFS客户端连接active namenode的java类</description>
		</property>

		<property>
			<name>dfs.ha.fencing.methods</name>
			<value>sshfence</value>
			<description>配置隔离机制为ssh</description>
		</property>
		
		<!-- 配置sshfence隔离机制超时时间 -->
		<property>
			<name>dfs.ha.fencing.ssh.connect-timeout</name>
			<value>30000</value>
		</property>

		<property>
			<name>dfs.ha.fencing.ssh.private-key-files</name>
			<value>$USER_PATH/.ssh/id_rsa</value>
			<description>使用隔离机制时需要ssh免密码登陆,指定秘钥的位置</description>
		</property>

		<property>
			<name>dfs.ha.automatic-failover.enabled</name>
			<value>true</value>
			<description>指定支持高可用自动切换机制,开启自动故障转移</description>
		</property>

		<property>
			<name>ha.zookeeper.quorum</name>
			<value>$ZOOKEEPER_PORT</value>
			<description>指定zookeeper地址</description>
		</property>

		<property>
			<name>dfs.replication</name>
			<value>3</value>
		</property>
		
		<!--
			<property>
				<name>dfs.namenode.name.dir</name>
				<value>file:$USER_SOFT_PATH/hadoop/datas/namenode</value>
				<description>新建name文件夹，指定namenode名称空间的存储地址</description>
			</property>

			<property>
				<name>dfs.datanode.data.dir</name>
				<value>file:$USER_SOFT_PATH/hadoop/datas/datanode</value>
				<description>新建data文件夹，指定datanode数据存储地址</description>
			</property>
		-->

		<property>
			<name>dfs.webhdfs.enabled</name>
			<value>ture</value>
			<description>指定可以通过web访问hdfs目录</description>
		</property>
		
		<!--配置文件中直接使用IP地址需设置该属性-->
		<property>
			<name>dfs.namenode.datanode.registration.ip-hostname-check</name>
			<value>false</value>
		</property>

	</configuration>
	" >> $hdfs_site

	#configure yarn-site.xml
	sed -i "/<configuration>/d" $yarn_site
	sed -i "/<\/configuration>/d" $yarn_site
	echo "
	<configuration>
		<property>
			<name>yarn.nodemanager.aux-services</name>
			<value>mapreduce_shuffle</value>
		</property>

		<property>
			<name>yarn.resourcemanager.ha.enabled</name>
			<value>true</value>
		</property>

		<property>
			<name>yarn.resourcemanager.cluster-id</name>
			<value>yarncluster</value>
			<description>指定YARN HA的名称</description>
		</property>

		<property>
			<name>yarn.resourcemanager.ha.rm-ids</name>
			<value>rm1,rm2</value>
			<description>指定两个resourcemanager的名称</description>
		</property>

		<property>
			<name>yarn.resourcemanager.hostname.rm1</name>
			<value>$NN01</value>
			<description>配置rm1的主机</description>
		</property>

		<property>
			<name>yarn.resourcemanager.hostname.rm2</name>
			<value>$NN02</value>
			<description>配置rm2的主机</description>
		</property>

		<property>
			<name>yarn.resourcemanager.zk-address</name>
			<value>$ZOOKEEPER_PORT</value>
			<description>配置zookeeper的地址</description>
		</property>

		<property>
			<name>yarn.resourcemanager.webapp.address.rm1</name>
			<value>$NN01:8088</value>
		</property>
		<property>
			<name>yarn.resourcemanager.webapp.address.rm2</name>
			<value>$NN02:8088</value>
		</property>
	</configuration>
	" >> $yarn_site

	#configure hadoop-env.sh
	sed -i "/^export JAVA_HOME=.*/c export JAVA_HOME=\\$USER_SOFT_PATH/java" $hadoop_env

	#configure slaves
	for IP in ${HADOOP_IPS[@]};
	do
		echo $IP >> $slaves
	done
	echo -e $SLAVES > $slaves

	sleep 1
	echo "正在设置环境变量..."
	#configure Environment variables
	echo "export HADOOP_HOME=$USER_SOFT_PATH/hadoop" >> $PROFILE
	oldpath=`grep '^export PATH=.*' $PROFILE`
	sed -i "/export PATH=/c \\$oldpath:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin" $PROFILE

	#远程拷贝
	sleep 1
	echo "正在远程拷贝..."
	for IP in ${HADOOP_IPS[@]};
	do
		if [ "${IP}" = "${LOCAL_HOST}" ];then
			source $PROFILE
		else
			scp -r $USER_SOFT_PATH/hadoop $USER@$IP:$USER_SOFT_PATH/
			scp $PROFILE $USER@$IP:$USER_PATH/
		fi 
	done	
	
	#启动journalnode
	sleep 1
	echo "正在启动journalnode..."
	for IP in ${HADOOP_IPS[@]};
	do
		if [ "${IP}" = "${LOCAL_HOST}" ];then
			source $PROFILE
			cd $USER_SOFT_PATH/hadoop
			sbin/hadoop-daemon.sh start journalnode
		else
			/usr/bin/expect <<-EOF
			spawn ssh ${IP}
			expect "*#" { send "source $PROFILE\r" }
			expect "*#" { send "cd $USER_SOFT_PATH/hadoop\r"}
			expect "*#" { send "sbin/hadoop-daemon.sh start journalnode\r"}
			expect "*#" { send "logout\r"}
			expect eof
			EOF
		fi 
	done
	
	if [ $? -eq 0 ];then
		sleep 1
		echo "正在格式化namenode..."
		#格式化
		#LOCAL_HOST=NN01(测试中两者相等,实际需要用条件判断一下)
		#ssh $NN01		
		if [ "$NN01" = "${LOCAL_HOST}" ];then
			$USER_SOFT_PATH/hadoop/bin/hdfs namenode -format
			$USER_SOFT_PATH/hadoop/bin/hdfs zkfc -formatZK
			#namenode元数据默认配置路径,如果配置文件中有修改,此处也要进行相应修改
			scp -r $USER_SOFT_PATH/hadoop/tmp $USER@$NN02:$USER_SOFT_PATH/hadoop/
		else
			/usr/bin/expect <<-EOF
			spawn ssh ${NN01}
			expect "*#" { send "$USER_SOFT_PATH/hadoop/bin/hdfs namenode -format\r" }
			expect "*#" { send "scp -r $USER_SOFT_PATH/hadoop/tmp $USER@$NN02:$USER_SOFT_PATH/hadoop/\r" }
			expect "*#" { send "$USER_SOFT_PATH/hadoop/bin/hdfs zkfc -formatZK\r"}
			expect "*#" { send "logout\r"}
			expect eof
			EOF
		fi 
	else
		echo "hadoop安装失败"
		exit 1
	fi
	
	sleep 1
	echo "正在启动hadoop集群..."
	#启动集群
	#LOCAL_HOST=NN01
	#ssh $NN01
	
	if [ "$NN01" = "${LOCAL_HOST}" ];then
		$USER_SOFT_PATH/hadoop/sbin/start-dfs.sh
		$USER_SOFT_PATH/hadoop/sbin/start-yarn.sh
		$USER_SOFT_PATH/hadoop/sbin/hadoop-daemon.sh start zkfc
	else
		/usr/bin/expect <<-EOF
		spawn ssh ${NN01}
		expect "*#" { send "$USER_SOFT_PATH/hadoop/sbin/start-dfs.sh\r" }
		expect "*#" { send "$USER_SOFT_PATH/hadoop/sbin/start-yarn.sh\r" }
		expect "*#" { send "$USER_SOFT_PATH/hadoop/sbin/hadoop-daemon.sh start zkfc\r"}
		expect "*#" { send "logout\r"}
		expect eof
		EOF
	fi 
		
	if [ "$NN02" = "${LOCAL_HOST}" ];then
		$USER_SOFT_PATH/hadoop/sbin/yarn-daemon.sh start resourcemanager
		$USER_SOFT_PATH/hadoop/sbin/hadoop-daemon.sh start zkfc
	else
		/usr/bin/expect <<-EOF
		spawn ssh $NN02
		expect "*#" { send "$USER_SOFT_PATH/hadoop/sbin/yarn-daemon.sh start resourcemanager\r" }
		expect "*#" { send "$USER_SOFT_PATH/hadoop/sbin/hadoop-daemon.sh start zkfc\r"}
		expect "*#" { send "logout\r"}
		expect eof
		EOF
	fi 	
	
	if [ $? -eq 0 ];then
		echo "hadoop安装成功,hadoop集群已启动"
	else
		echo "hadoop安装失败"
		exit 1
	fi
}

function install_Hbase(){
	echo "============正在安装hbase============"

	#准备regionservers
	REGIONSERVERS=""
	for((i=0;i<${#HB_IPS[@]};i++));
	do
		REGIONSERVERS="$REGIONSERVERS${HB_IPS[$i]}\n"
	done
	REGIONSERVERS=`echo ${REGIONSERVERS%'\n'}`

	#对zookeeper的ip和port进行拼接
	ZOOKEEPER_PORT=""	
	for((i=0;i<${#ZK_IPS[@]};i++));
	do
		ZOOKEEPER_PORT="$ZOOKEEPER_PORT${ZK_IPS[$i]}:2181,"
	done
	ZOOKEEPER_PORT=`echo ${ZOOKEEPER_PORT%,}`  

	#解压hbase安装包
	echo "正在解压hbase安装包,请稍等..."
	cp ./$HBASE_NAME $USER_INSTALL_PATH
	tar -zxvf $USER_INSTALL_PATH/$HBASE_NAME -C $USER_SOFT_PATH
	mv $USER_SOFT_PATH/$HBASE $USER_SOFT_PATH/hbase

	#开始配置hbase
	cp $USER_SOFT_PATH/hadoop/etc/hadoop/core-site.xml $USER_SOFT_PATH/hbase/conf
	cp $USER_SOFT_PATH/hadoop/etc/hadoop/hdfs-site.xml $USER_SOFT_PATH/hbase/conf

	hbase_env="$USER_SOFT_PATH/hbase/conf/hbase-env.sh"
	hbase_site="$USER_SOFT_PATH/hbase/conf/hbase-site.xml"
	regionservers="$USER_SOFT_PATH/hbase/conf/regionservers"

	sleep 1
	echo "正在设置配置文件..."
	#configure hbase-env.sh
	sed -i "/^#.*export JAVA_HOME=.*/a export JAVA_HOME=\\$USER_SOFT_PATH/java" $hbase_env
	sed -i "/^#.*export HBASE_MANAGES_ZK=.*/a export HBASE_MANAGES_ZK=FALSE" $hbase_env

	#configure hbase-site.xml
	sed -i "/<configuration>/d" $hbase_site
	sed -i "/<\/configuration>/d" $hbase_site
	echo "
	<configuration>
	  <property>
		  <name>hbase.rootdir</name>
		  <value>hdfs://hdfscluster:8020/hbase</value>
	  </property>

	  <property>
		  <name>hbase.cluster.distributed</name>
		  <value>true</value>
	  </property>

	  <property>
		  <name>hbase.zookeeper.quorum</name>
		  <value>$ZOOKEEPER_PORT</value>
	  </property>

	  <property>
		  <name>hbase.zookeeper.property.dataDir</name>
		  <value>$USER_SOFT_PATH/zookeeper/data</value>
	  </property>
	</configuration>
	" >> $hbase_site

	#configure regionservers
	echo -e $REGIONSERVERS > $regionservers

	sleep 1
	echo "正在设置环境变量..."
	#configure Environment variables
	echo "export HBASE_HOME=$USER_SOFT_PATH/hbase" >> $PROFILE
	oldpath=`grep '^export PATH=.*' $PROFILE`
	sed -i "/export PATH=/c \\$oldpath:\$HBASE_HOME/bin" $PROFILE
	#echo "export PATH=\$HBASE_HOME/bin:\$PATH" >> $PROFILE

	#远程拷贝
	sleep 1
	echo "正在远程拷贝..."
	for IP in ${HB_IPS[@]};
	do
		if [ "${IP}" = "${LOCAL_HOST}" ];then
			source $PROFILE
		else
			scp -r $USER_SOFT_PATH/hbase $USER@$IP:$USER_SOFT_PATH/
			scp $PROFILE $USER@$IP:$USER_PATH/
		fi
	done
	
	if [ $? -eq 0 ];then
		for IP in ${HB_IPS[@]};
		do
			if [ "${IP}" = "${LOCAL_HOST}" ];then
				hbase version
				echo "${IP} hbase安装成功"
			else
				/usr/bin/expect <<-EOF
					spawn ssh ${IP}
					expect "*#" { send "source $PROFILE\r" }
					expect "*#" { send "hbase version\r"}
					expect "*#" { send "echo $IP hbase安装成功\r"}
					expect "*#" { send "logout\r"}
					expect eof
				EOF
			fi
		done
		
		$USER_SOFT_PATH/hbase/bin/start-hbase.sh
		if [ $? -eq 0 ];then
			echo "hbase已启动"
		else
			echo "hbase启动失败"
		fi
		
	else
		echo "hbase安装失败"
		exit 1
	fi
}

function install_Kafka(){ 
	echo "============开始安装kafka============"
	#对zookeeper的ip和port进行拼接
	ZOOKEEPER_PORT=""
	for((i=0;i<${#ZK_IPS[@]};i++));
	do
	ZOOKEEPER_PORT="$ZOOKEEPER_PORT${ZK_IPS[$i]}:2181,"
	done
	ZOOKEEPER_PORT=`echo ${ZOOKEEPER_PORT%,}`  

	echo "正在解压kafka安装包,请稍等..."
	#解压kafka安装包
	cp ./$KAFKA_NAME $USER_INSTALL_PATH
	tar -zxvf $USER_INSTALL_PATH/$KAFKA_NAME -C $USER_SOFT_PATH
	mv $USER_SOFT_PATH/$KAFKA $USER_SOFT_PATH/kafka

	sleep 1
	echo "正在设置配置文件..."
	#开始配置kafka
	property="$USER_SOFT_PATH/kafka/config/server.properties"
	#configure server.properties
	mkdir -p $USER_SOFT_PATH/kafka/logs
	KAFKA_LOGS=$USER_SOFT_PATH/kafka/logs
	KAFKA_LOGS=$(echo $KAFKA_LOGS |sed -e 's/\//\\\//g')
	sed -i "s/^zookeeper\.connect=.*host:2181$/zookeeper.connect=$ZOOKEEPER_PORT/g" $property
	sed -i "s/^log\.dirs=.*ka-logs$/log.dirs=${KAFKA_LOGS}/g" $property
	echo -e "\ndelete.topic.enable=true" >> $property
	
	sleep 1
	echo "正在设置环境变量..."
	#configure Environment variables
	echo "export KAFKA_HOME=$USER_SOFT_PATH/kafka" >> $PROFILE
	oldpath=`grep '^export PATH=.*' $PROFILE`
	sed -i "/export PATH=/c \\$oldpath:\$KAFKA_HOME/bin" $PROFILE

	#远程拷贝
	sleep 1
	echo "正在远程拷贝..."
	for IP in ${KAFKA_IPS[@]};
	do
		if [ "${IP}" = "${LOCAL_HOST}" ];then
			source $PROFILE
		else
			scp -r $USER_SOFT_PATH/kafka $USER@$IP:$USER_SOFT_PATH/
			scp $PROFILE $USER@$IP:$USER_PATH/
		fi
	done
	
	#配置各节点上的server.properties
	properties="$USER_SOFT_PATH/kafka/config/server.properties"
	for((i=0;i<${#KAFKA_IPS[@]};i++));
	do
		if [ "${KAFKA_IPS[$i]}" = "${LOCAL_HOST}" ];then
			sed -i "s/broker\.id=0/broker.id=$i/g" $properties
			sed -i "/#listeners=PLAINTEXT:\/\/:9092/a\listeners=PLAINTEXT://${KAFKA_IPS[$i]}:9092" $properties
			source $PROFILE
		else
			/usr/bin/expect <<-EOF
					spawn ssh ${KAFKA_IPS[$i]}
					expect "*#" { send "sed -i 's/broker\.id=0/broker.id=$i/g' $properties\r" }
					expect "*#" { send "sed -i \"/#listeners=PLAINTEXT:\\\/\\\/:9092/a listeners=PLAINTEXT://${KAFKA_IPS[$i]}:9092\" $properties\r"}
					expect "*#" { send "source $PROFILE\r"}
					expect "*#" { send "logout\r"}
					expect eof
				EOF
		fi
	done
	
	if [ $? -eq 0 ];then
		echo "kafka安装成功"
		echo "启动kafka之前,请先启动zookeeper"
	else
		echo "kafka安装失败"
		exit 1
	fi
}
function start_Kafka(){
	echo "正在启动kafka..."	
	for IP in ${KAFKA_IPS[@]};
	do
		if [ "${IP}" = "${LOCAL_HOST}" ];then
			nohup $USER_SOFT_PATH/kafka/bin/kafka-server-start.sh $USER_SOFT_PATH/kafka/config/server.properties > /dev/null 2>&1 &
			echo "${IP} kafka已启动"
		else
			/usr/bin/expect <<-EOF
					spawn ssh $IP
					expect "*#" { send "nohup $USER_SOFT_PATH/kafka/bin/kafka-server-start.sh $USER_SOFT_PATH/kafka/config/server.properties > /dev/null 2>&1 &\r" }
					expect "*#" { send "echo ${IP} kafka已启动\r"}
					expect "*#" { send "logout\r"}
					expect eof
				EOF
		fi
	done
}
function stop_Kafka(){
	echo "正在停止kafka..."
	
	for IP in ${KAFKA_IPS[@]};
	do
		if [ "${IP}" = "${LOCAL_HOST}" ];then
			nohup $USER_SOFT_PATH/kafka/bin/kafka-server-stop.sh > /dev/null 2>&1 &
			echo "$IP kafka已停止"
		else
			/usr/bin/expect <<-EOF
					spawn ssh $IP
					expect "*#" { send "nohup $USER_SOFT_PATH/kafka/bin/kafka-server-stop.sh > /dev/null 2>&1 &\r" }
					expect "*#" { send "echo ${IP} kafka已停止\r"}
					expect "*#" { send "logout\r"}
					expect eof
				EOF
		fi
	done
}

case $1 in
"keygen"){
        keygen
};;
"disableFireWalld"){
        disableFireWalld
};;
"install_JDK"){
        install_JDK
};;
"install_Zookeeper"){
        install_Zookeeper
};;
"start_Zookeeper"){
        start_Zookeeper
};;
"stop_Zookeeper"){
        stop_Zookeeper
};;
"install_Hadoop"){
        install_Hadoop
};;
"install_Hbase"){
        install_Hbase
};;
"install_Kafka"){
        install_Kafka
};;
"start_Kafka"){
        start_Kafka
};;
"all"){
        keygen
		disableFireWalld
		install_JDK
		install_Zookeeper
		start_Zookeeper
		install_Hadoop
		install_Hbase
		install_Kafka
		start_Kafka
};;
esac
