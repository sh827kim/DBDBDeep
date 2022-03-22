# 원활한 스터디를 위한 사전 과제

첫번째 세션 수업을 원활히 진행하기 위해서, 시간이 많이 걸리는 설치 작업에 대해서 아래와 같이 사전 가이드를 드립니다.

가급적 아래 과정을 따라하며 DB 설치에 대해서는 사전에 미리 진행해주시면 감사하겠습니다.

개인적으로 검증을 마쳤으나, 혹시 아래 가이드대로 따라했을 때 잘 안된다면 언제든지 문의주세요!

## DB 설치

### [사전 작업]리눅스(CentOS) 환경 세팅 (With.Mac)

1. centos 이미지를 받아서 실행합니다.

```shell
docker pull centos:8
docker run --privileged --name mycentos -p 15432:5432 -d centos:8 /sbin/init
```

2. 실행 후 아래 명령어로 접속을 하여 이상이 없는지 확인합니다.

```
docker exec -it mycentos /bin/bash
```

3. yum(dnf) repo를 정상적으로 사용하기 위한 셋업 작업을 합니다.

```
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Linux-*
sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-Linux-*
```

4. lang pack을 설치한 후 기본 언어를 en_US.UTF-8로 변경합니다.

```shell
dnf install -y glibc-langpack-en
localectl set-locale LANG=en_US.UTF-8
```

5. 그 외 편의를 위해 sudo, net-tools를 깔아줍니다.

```shell
dnf install -y sudo net-tools
```





### DB 설치

1. postgresql을 설치하기 위해 필요한 rpm을 추가합니다.

```shell
dnf install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm -y
```

2. 원래 깔려있는 postgresql을 disable하고 postgresql을 설치합니다.

```
dnf -qy module disable postgresql
dnf install -y postgresql14-server
```

3. 설치한 postgresql을 아래 명령어를 통해 초기화를 합니다.

```shell
sudo /usr/pgsql-14/bin/postgresql-14-setup initdb
```

4. 도커 밖에서도 DB 접근이 가능하도록 아래와 같이 네트워크 셋팅을 변경해줍니다.

```shell
vi /var/lib/pgsql/14/data/pg_hba.conf
```

```shell
...
# "local" is for Unix domain socket connections only
local   all             all                                     peer
# IPv4 local connections:
host    all             all             0.0.0.0/0               md5
# IPv6 local connections:
host    all             all             ::1/128                 md5
...
```

```shell
vi /var/lib/pgsql/14/data/postgresql.conf
```

```
...
listen_addresses = '*'
...
```

4. postgresql을 실행하고, 문제 없는지 확인합니다.

```shell
systemctl enable postgresql-14
systemctl start postgresql-14
systemctl status postgresql-14
```



### 초기 유저 셋업

1. postgresql을 설치하며 자동으로 생성된 리눅스 유저 postgres로 전환합니다.

```shell
su - postgres
```

2. psql 명령어를 통해 커맨드 창에서 postgres를 컨트롤 할 수 있도록 합니다.

```
psql
```

3. postgres role대해서 패스워드를 설정해준 후 psql을 종료합니다.

```shell
postgres=# alter role postgres with password 'study1234!';
postgres=# \q
logout
```

