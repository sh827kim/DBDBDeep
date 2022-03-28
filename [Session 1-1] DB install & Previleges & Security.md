# Session 1. DB 설치, 권한, 보안

본 세션은 Postgresql을 기준으로 작성되었습니다.

실습은 개발용 PC 기준으로 작성하였습니다.



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



### [참조] PC를 껐다 켰더니 설치한 postgresql docker가 죽었는데 어떻게 하죠?

아래 명령어를 통해 살리시면 됩니다. 굳이 docker를 삭제하기 전에는 volume이 휘발성으로 날아가는 게 아니므로, 그동안 작업한 내용들은 멀쩡히 살아 있으니 안심하셔도 좋습니다.

```bash
docker start mycentos
```

또는 아래와 같이 postgresql 도커 기반의 컴포즈 파일로 진행하셔도 무방합니다. 

사전에 공유해드린  sql 파일을 init_schema 폴더에 추가하면 샘플스키마도 함께 create 되니 참조하시기 바랍니다.

(link : https://github.com/sh827kim/DBDBDeep/tree/master/docker)

단, 마운팅 할 위치를 적당히 수정해주시기 바랍니다.

```yaml
version: '3.1'
services:
  postgres:
    image: postgres:latest
    container_name: postgres
    restart: always
    ports:
      - "25432:5432"
    volumes:
      - YOUR_DATA_DIR:/var/lib/postgresql/data
      - YOUR_MOUNT_BASE_DIR/init_schema:/docker-entrypoint-initdb.d
    environment:
      POSTGRES_PASSWORD: mytest1234
      POSTGRES_DB: dvdrental
```



## 권한

최신 PostgreSQL 의 경우 Role 을 기반으로 계정 생성 및 데이터베이스 권한을 관리합니다.

PostgreSQL에서의 Role 이란, USER, GROUP의 개념을 모두 포함하고 있습니다. (예전에는 USER, GROUP이 분리되어 있었음.)

그러나 여전히 관례상 `CREATE USER`, `CREATE GROUP` 같은 구문을 허용하고 있습니다.

현재 DB에 존재하는 Role을 확인하기 위해서는 아래 구문을 활용할 수 있습니다.

```sql
SELECT rolname FROM pg_roles;
```

### role 생성/변경/삭제 - CREATE, ALTER, DROP

Role은 `CREATE`, `DROP `을 통해 생성, 삭제할 수 있습니다. `CREATE`은 Role 생성 뿐만 아니라, 속성을 부여할 수 있습니다. 이미 생성한 Role에 대해서는 `ALTER` 구문을 활용하여 속성을 변경할 수 있습니다.

Role 에 별도로 LOGIN 속성을 부여하지 않는다면 GROUP으로 취급이 되고, LOGIN 속성을 부여한다면 USER로 취급됩니다.

```sql
CREATE ROLE dbdbdeep; # GROUP 취급
CREATE ROLE spark LOGIN; # USER 취급
DROP ROLE #{NAME};
```

CREATE 구문을 통해 부여할 수 있는 속성은 아래와 같습니다.

| 구분                                   | 설명                                                         | ALTER |
| -------------------------------------- | ------------------------------------------------------------ | ----- |
| `SUPERUSER`  <br>`NOSUPERUSER`(default) |슈퍼 유저인지    | O                                               |
| `CREATEDB` <br>`NOCREATEDB`(default) |데이터 베이스를 생성하는 역할인지       | O                            |
| `CREATEROLE` <br>`NOCREATEROLE`(default) |새 역할을 생성하는 역할인지   | O     |
| `INHERIT`(default) <br>`NOINHERIT` |다른 role이 해당 role의 권한을 자동 상속하게 할 건지         | O         |
| `LOGIN`<br>`NOLOGIN`(default) |로그인 가능한 역할인지             | O                                       |
| `REPLICATION`<br>`NOREPLICATION`(default) |복제 역할인지 (replication 서버 관련) | O                        |
| `BYPASSRLS`<br>`NOBYPASSRLS`(default) |RLS 정책을 우회하는지에 대한 여부     | O                            |
| `CONNECTION LIMIT`                     | 역할이 만들 수 있는 동시 연결 세션 제한 수 (기본값: 제한없음 (-1)) | O     |
| [`ENCRYPTED`]`PASSWORD` 'password'     | 역할의 암호를 설정                                           | O     |
| `VALID UNTIL` 'timestamp'              | 암호 유효성 만료 날짜 지정 (기본값: 만료 없음)               | O     |
| `IN ROLE` 'role_name'                  | 새로 생성하는 role에 기존 역할을 추가 (admin은 IN ROLE로 추가 불가능)<br>`CREATE ROLE spark IN ROLE captain;` | X     |
| `ROLE` 'role_name'                     | 새로 생성하는 role에 포함시킬 role들을 나열. <br>`CREATE ROLE crew ROLE spark, jason;` | X     |
| `ADMIN` 'role_name'                    | `ROLE` 구문과 거의 동일하나, `WITH ADMIN OPTION`을 추가한 효과.<br>(다른 role에 이 role을 부여할 수 있는 자격이 함께 생김) | X     |



###권한 - GRANT/REVOKE

`GRANT`/`REVOKE`는 DCL로, Object 에 대한 권한을 부여/회수합니다.

```sql
GRANT *privilege* ON *Object* TO *role*;
REVOKE *privilege* ON *Object* FROM *role*;
```



**권한의 종류**

| privileges       | 설명                                                         |
| ---------------- | ------------------------------------------------------------ |
| `SELECT`         | Table, View, Sequence 데이터 조회 권한<br>COPY(copy data between a file and a table)하기 위한 권한 <br>Update 또는 Delete 시 존재하는 컬럼 값들을 참조하기 위한 권한<br>Sequence의 currval 함수 사용을 위한 권한<br>Large Object에 대한 read를 위한 권한 |
| `INSERT`         | 테이블, 특정 컬럼에 대해 데이터 삽입 권한<br>COPY 받기 위한 권한 |
| `UPDATE`         | Table 데이터 갱신 권한<br>Sequence의 nextval과 setval 함수 사용을 위해 필요<br>Select .. for update, select ... for share 수행을 위해 필요 |
| `DELETE`         | 테이블 데이터 삭제 권한                                      |
| `TRUNCATE`       | 테이블 Truncate 수행 권한                                    |
| `REFERENCES`     | 외래키 제약 조건을 생성할 수 있는 권한                       |
| `TRIGGER`        | TABLE에 대한 트리거 생성할 수 있는 권한                      |
| `CREATE`         | DATABASE, SCHEMA, TABLESPACE를 생성할 수 있는 권한           |
| `CONNECT`        | DATABASE 에 연결할 수 있는 권한을 부여                       |
| `TEMPORARY`      | DATABASE를 사용하는 동안 임시 테이블을 생성할 수 있는 권한   |
| `EXECUTE`        | FUNCTION, PROCEDURE 를 호출할 수 있는 권한                   |
| `USAGE`          | For Procedural Language : Function을 만들기 위해 사용되는 특정 language에 대한 사용 권한 <br>For Schema : 스키마 안의 object 사용 권한 (최초 catalog 정보만 확인 가능)<br>For Sequence : currval 와 nextval 함수를 사용하기 위한 권한<br>For Type and domain : 테이블, 함수 등의 Object 생성 시 type과 domain에 대한 사용권한<br> |
| `ALL PRIVILEGES` | 모든 권한 부여                                               |



### [실습 사전 작업] 샘플 스키마 생성

실습에 앞서 테스트를 위한 샘플 스키마를 생성합니다.

- wget, unzip 설치

```shell
docker exec -it mycentos bash
dnf install -y wget unzip
```

- 샘플 스키마 다운로드 및 압축해제

```bash
su - postgres
wget https://www.postgresqltutorial.com/wp-content/uploads/2019/05/dvdrental.zip
unzip dvdrental
```

- create database

```bash
psql
postgres=# create database dvdrental owner postgres;
postgres=# \q
```

- 스키마 복원

```bash
pg_restore -h localhost -p 5432 -U postgres -d dvdrental -v "./dvdrental.tar"
```

### [실습] 여러가지 역할 생성, 권한부여

1. postgres 대신 사용할 슈퍼유저 생성해보기.

```sql
CREATE ROLE dvdadmin WITH SUPERUSER LOGIN PASSWORD 'mytest1234';
GRANT ALL ON DATABASE dvdrental to dvdadmin;
```

2. actor 테이블에 대해 SELECT, UPDATE, INSERT, DELETE 권한만 가진 유저 생성해보기

- dvdadmin

```sql
CREATE ROLE dvddev WITH LOGIN PASSWORD 'mytest1234';
GRANT SELECT UPDATE INSERT DELETE ON actor TO dvddev;
```

- dvddev

```sql
SELECT * FROM actor;
```

3. 2번에서 생성한 유저에게서 DELETE 권한을 회수한 후 DELETE 수행이 불가능한지 확인해보기

- dvdadmin

```sql
REVOKE DELETE ON actor from dvddev;
```

- dvddev

```sql
DELETE FROM actor where actor_id = 1;
```





## 보안

- 정보 보안 : 비인가된 접근, 사용, 노출, 파괴, 변경, 탐색, 조사, 기록 또는 파기 등으로부터 정보와 정보 시스템을 보호하는 것.
  - 데이터의 형태나 위치에 상관 없이 데이터의 기밀성, 가용성, 무결성을 보호하는 데에 초점
- DB 보안 : DB와 DB 내 저장된 데이터를 비인가된 변경, 파괴, 노출 및 비일관성을 발생시키는 사건이나 위협으로부터 보호하는 것.
  - 

