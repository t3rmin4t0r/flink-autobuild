
YUM:=$(shell which yum)
APT:=$(shell which apt-get)
HADOOP:=$(shell which hadoop)
TOOLS=git gcc cmake pdsh
TEZ_VERSION=0.8.0-SNAPSHOT
TEZ_BRANCH=master
FLINK_VERSION=0.10-SNAPSHOT
FLINK_BRANCH=master
HDFS=$(shell id hdfs 2> /dev/null)
# try to build against local hadoop always
ifneq ($(HADOOP),)
	HADOOP_VERSION=$(shell hadoop version | grep "^Hadoop" | cut -f 2 -d' ')
else
	HADOOP_VERSION=2.6.0
endif
APP_PATH:=$(shell echo /user/$$USER/apps/flink-`date +%Y-%b-%d`/)
HISTORY_PATH:=$(shell echo /user/$$USER/tez-history/build=`date +%Y-%b-%d`/)
INSTALL_ROOT:=$(shell echo $$PWD/dist/)
HIVE_CONF_DIR=/etc/hive/conf/
#override this in local.mk to point to jdbc jars etc 
#AUX_JARS_PATH=/home/gopal/postgres/*:/usr/share/java/*
HS2_PORT=10002
OFFLINE=false
REBASE=false
CLEAN=clean

-include local.mk

#ifneq ($(HDFS),)
#	AS_HDFS=sudo -u hdfs env PATH=$$PATH JAVA_HOME=$$JAVA_HOME HADOOP_HOME=$$HADOOP_HOME HADOOP_CONF_DIR=$$HADOOP_CONF_DIR bash
#else
	AS_HDFS=bash
#endif

git: 
ifneq ($(YUM),)
	which $(TOOLS) || yum -y install git-core \
	gcc gcc-c++ \
	pdsh \
	cmake \
	zlib-devel openssl-devel 
endif
ifneq ($(APT),)
	which $(TOOLS) || apt-get install -y git gcc g++ python man cmake zlib1g-dev libssl-dev 
endif

maven: 
	$(OFFLINE) || wget -c http://www.us.apache.org/dist/maven/maven-3/3.0.5/binaries/apache-maven-3.0.5-bin.tar.gz
	-- mkdir -p $(INSTALL_ROOT)/maven/
	tar -C $(INSTALL_ROOT)/maven/ --strip-components=1 -xzvf apache-maven-3.0.5-bin.tar.gz

ant: 
	$(OFFLINE) || wget -c http://archive.apache.org/dist/ant/binaries/apache-ant-1.9.1-bin.tar.gz
	-- mkdir -p $(INSTALL_ROOT)/ant/
	tar -C $(INSTALL_ROOT)/ant/ --strip-components=1 -xzvf apache-ant-1.9.1-bin.tar.gz
	-- yum -y remove ant

protobuf: git 
	$(OFFLINE) || wget -c http://protobuf.googlecode.com/files/protobuf-2.5.0.tar.bz2
	tar -xvf protobuf-2.5.0.tar.bz2
	test -f $(INSTALL_ROOT)/protoc/bin/protoc || \
	(cd protobuf-2.5.0; \
	./configure --prefix=$(INSTALL_ROOT)/protoc/; \
	make -j4; \
	make install -k)

clean-protobuf:
	rm -rf protobuf-2.5.0/

mysql: 
	$(OFFLINE) || wget -c http://repo1.maven.org/maven2/mysql/mysql-connector-java/5.1.29/mysql-connector-java-5.1.29.jar

tez: git maven protobuf
	test -d tez || git clone --branch $(TEZ_BRANCH) https://git-wip-us.apache.org/repos/asf/tez.git tez
	export PATH=$(INSTALL_ROOT)/protoc/bin:$(INSTALL_ROOT)/maven/bin/:$$PATH; \
	cd tez/; . /etc/profile; \
	mvn $(CLEAN) package install -DskipTests -Dhadoop.version=$(HADOOP_VERSION) -Phadoop24 -P\!hadoop26 $$($(OFFLINE) && echo "-o");
	# for hadoop version < 2.4.0, use -P\!hadoop24 -P\!hadoop26

clean-tez:
	rm -rf tez

flink: tez-dist.tar.gz 
	test -d flink || git clone --branch $(FLINK_BRANCH) git@github.com:apache/flink.git
	cd flink; if $(REBASE); then (git stash; git clean -f -d; git pull --rebase;); fi
	export PATH=$(INSTALL_ROOT)/protoc/bin:$(INSTALL_ROOT)/maven/bin/:$(INSTALL_ROOT)/ant/bin:$$PATH; \
	cd flink/; . /etc/profile; \
	mvn $(CLEAN) package -DskipTests -Pjdk8 -Pinclude-tez -Pinclude-yarn -Dhadoop.version=$(HADOOP_VERSION) -Dtez.version=$(TEZ_VERSION) $$($(OFFLINE) && echo "-o");

clean-flink:
	rm -rf flink

dist-tez: tez 
	cp tez/tez-dist/target/tez-$(TEZ_VERSION).tar.gz tez-dist.tar.gz

dist-flink: mysql flink
	tar -C flink/flink-staging/flink-tez/target/ -czvf flink-dist.tar.gz flink-tez-$(FLINK_VERSION)-flink-fat-jar.jar

tez-dist.tar.gz:
	@echo "run make dist to get tez-dist.tar.gz"

flink-dist.tar.gz:
	@echo "run make dist to get tez-dist.tar.gz"

dist: dist-tez dist-flink

install: tez-dist.tar.gz flink-dist.tar.gz
	rm -rf $(INSTALL_ROOT)/tez
	mkdir -p $(INSTALL_ROOT)/tez/conf
	tar -C $(INSTALL_ROOT)/tez/ -xzvf tez-dist.tar.gz
	cp -v tez-site.xml $(INSTALL_ROOT)/tez/conf/
	sed -i~ "s@/apps@$(APP_PATH)tez@g" $(INSTALL_ROOT)/tez/conf/tez-site.xml
	sed -i~ "s@/tez-history/@$(HISTORY_PATH)@g" $(INSTALL_ROOT)/tez/conf/tez-site.xml
	$(AS_HDFS) -c "hadoop fs -rm -R -f $(APP_PATH)/tez/"
	$(AS_HDFS) -c "hadoop fs -mkdir -p $(APP_PATH)/tez/aux"
	$(AS_HDFS) -c "hadoop fs -copyFromLocal -f tez-dist.tar.gz $(APP_PATH)/tez/"
	rm -rf $(INSTALL_ROOT)/flink
	mkdir -p $(INSTALL_ROOT)/flink
	tar -C $(INSTALL_ROOT)/flink -xzvf flink-dist.tar.gz
	$(AS_HDFS) -c "hadoop fs -rm -f $(APP_PATH)/tez/aux/flink-tez-$(FLINK_VERSION)-flink-fat-jar.jar"
	$(AS_HDFS) -c "hadoop fs -copyFromLocal -f $(INSTALL_ROOT)/flink/flink-tez-$(FLINK_VERSION)-flink-fat-jar.jar $(APP_PATH)/tez/aux"
	$(AS_HDFS) -c "hadoop fs -chmod -R a+r $(APP_PATH)/"

clean-dist:
	rm -rf $(INSTALL_ROOT)

clean-all: clean clean-tez clean-flink clean-protobuf

clean: clean-dist

.PHONY: flink tez protobuf ant maven
