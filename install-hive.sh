#!/bin/bash
#This script is only used to root

USER=root
USER_PATH=/$USER
USER_INSTALL_PATH=$USER_PATH/install
USER_SOFT_PATH=$USER_PATH/software
PROFILE=$USER_PATH/.bash_profile

HIVE_NAME="apache-hive-1.2.2-bin.tar.gz"
HIVE=apache-hive-1.2.2-bin
MYSQL_CONNECT="mysql-connector-java-5.1.46.jar"

if [ ! -n "$1" ] ;then
    echo "请输入参数"
	exit 1
fi

if [ -n "$2" ] ;then
    MYSQL_PW=$2
else 
    MYSQL_PW=123456
fi

function install_Mysql(){
	echo "============开始安装mysql============"
	yum install -y wget
	wget -i -c http://dev.mysql.com/get/mysql57-community-release-el7-10.noarch.rpm
	yum -y install mysql57-community-release-el7-10.noarch.rpm
	
	yum -y install mysql-community-server
	systemctl start  mysqld.service
	systemctl status mysqld.service
	
	if [ $? -eq 0 ];then
		echo "mysql安装成功"
	else
		echo "mysql安装失败"
		exit 1
	fi
	
	echo "在安装hive前,请修改mysql密码,并进行授权"
	# grep "password" /var/log/mysqld.log
	# aqwT:wOuH8ts
	# mysql -uroot -p
	# SET PASSWORD=PASSWORD("$LOCAL_HOST_PW");
	# show databases;
	# use mysql;
	# update user set host='%' where host='localhost';
	# flush privileges;
	# quit;
}

function install_Hive(){
	echo "============开始安装hive============"
	sleep 1
    echo "正在解压hive安装包,请稍等..."
    #解压kafka安装包
    cp ./$HIVE_NAME $USER_INSTALL_PATH
    tar -zxvf $USER_INSTALL_PATH/$HIVE_NAME -C $USER_SOFT_PATH
    mv $USER_SOFT_PATH/$HIVE $USER_SOFT_PATH/hive

    sleep 1
    echo "正在设置配置文件..."
    #开始配置hive
	cp $USER_SOFT_PATH/hive/conf/hive-default.xml.template $USER_SOFT_PATH/hive/conf/hive-site.xml
	hive_site="$USER_SOFT_PATH/hive/conf/hive-site.xml"
    
	#configure hive-site.xml
	sed -i "s/--><configuration>/--><!-- <configuration>/g" $hive_site
    sed -i "/<configuration>/a -->" $hive_site
	sed -i "/<\/configuration>/i <!--" $hive_site
	sed -i "/<\/configuration>/a -->" $hive_site
	sed -i "/<property>/i <!--" $hive_site
	sed -i "/<\/property>/a -->" $hive_site
	echo "
	<configuration>
		<!--这个是用于存放hive元数据的hdfs目录位置 -->
		<property> 
			<name>hive.metastore.warehouse.dir</name>  
			<value>/hive/warehouse</value>  
		</property> 
		
		<!-- 控制hive是否连接一个远程metastore服务器还是开启一个本地客户端jvm，默认是true，Hive0.10已经取消了该配置项；-->
		<property>  
			<name>hive.metastore.local</name>  
			<value>true</value>  
		</property>
		
		<!-- JDBC连接字符串，默认jdbc:derby:;databaseName=metastore_db;create=true；-->
		<property>  
		  <name>javax.jdo.option.ConnectionURL</name>  
		  <value>jdbc:mysql://localhost/hive_remote?createDatabaseIfNotExist=true</value>  
		</property>  
	
		<!--JDBC的driver，默认org.apache.derby.jdbc.EmbeddedDriver； -->
		<property>  
		    <name>javax.jdo.option.ConnectionDriverName</name>  
		    <value>com.mysql.jdbc.Driver</value>  
		</property>  

		<!-- username -->
		<property>  
			<name>javax.jdo.option.ConnectionUserName</name>  
			<value>$USER</value>  
		</property>
  
		<!-- password,将mysql密码设为和localhost密码一致 -->
		<property>  
			<name>javax.jdo.option.ConnectionPassword</name>  
			<value>$MYSQL_PW</value>  
		</property>
	</configuration>
	" >> $hive_site
	
	cp ./$MYSQL_CONNECT $USER_SOFT_PATH/hive/lib/

    sleep 1
    echo "正在设置环境变量..."
    #configure Environment variables
    echo "export HIVE_HOME=$USER_SOFT_PATH/hive" >> $PROFILE
    oldpath=`grep '^export PATH=.*' $PROFILE`
    sed -i "/export PATH=/c \\$oldpath:\$HIVE_HOME/bin" $PROFILE
	
	cd 
	source $PROFILE
	hive --version
	
	if [ $? -eq 0 ];then
		echo "hive安装成功"
	else
		echo "hive安装失败"
		exit 1
	fi
}

case $1 in
"install_Mysql"){
        install_Mysql
};;
"install_Hive"){
        install_Hive
};;
esac