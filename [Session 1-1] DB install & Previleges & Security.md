# DB 설치, 권한, 보안

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
host    all             all             0.0.0.0/0               scram-sha-256
# IPv6 local connections:
host    all             all             ::1/128                 scram-sha-256
...
```

```shell
vi /var/lib/pgsql/14/data/postgresql.conf
```

```properties
...
listen_addresses = '*'
...
password_encryption = scram-sha-256
```

4. postgresql을 실행하고, 문제 없는지 확인합니다.

```bash
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



### [참조] 실습용 docker 이미지 및 docker-compose 파일 공유

설치절차를 실습하기 위해 위 절차들을 하나하나 실습하였으나, 도커 볼륨 설정 등 새로 띄우고 싶을 때 다시 설치해야해서 시간을 잡아먹는 것을 방지하기 위해 설정을 거의 마친 버전의 docker 이미지를 제작하였습니다. 아래 docker-compose 파일을 이용해 실행하시면 되겠습니다. 

(아래 절차 진행 후 초기 유저 셋업 절차 진행)

```bash
docker-compose -f pgcentos-docker.yaml up -d
docker exec -it pgcentos bash /pg_initialize.sh
```

```yaml
version: '3.1'
services:
  postgres:
    image: sh827kim/pgcentos:2
    container_name: mycentos
    privileged: true
    restart: always
    ports:
      - "15432:5432"
    volumes:
      - YOUR_DATA_DIR:/var/lib/pgsql/14  # 본인의 마운팅 위치를 YOUR_DATA_DIR에 작성해주세요.
      - YOUR_ARCHIVE_DIR:/mnt/server/archivedir # 본인의 마운팅 위치를 YOUR_ARCHIVE_DIR에 작성해주세요.
```



또는 아래와 같이 postgresql 도커 기반의 컴포즈 파일로 진행하는 방법도 있습니다.

사전에 공유해드린  sql 파일을 init_schema 폴더에 추가하면 샘플스키마도 함께 create 되니 참조하시기 바랍니다.

(link : https://github.com/sh827kim/DBDBDeep/tree/master/docker)

단, 백업/복원 실습이 어려울 수 있으니 참조 바랍니다.

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





### 권한 - GRANT/REVOKE

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
unzip dvdrental.zip
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





## DB 보안

DB 보안은 굉장히 광범위해질 수 있는 내용입니다. 따라서 본 세션에서는 보안에 대해 간략히 소개하는 정도로만 진행합니다.

혹시 DB 보안에 대해 관심이 있다면 https://dataonair.or.kr/db-tech-reference/d-guide/db-security 참조 바랍니다.



### DB 보안 개요

- 보안(Security) : 안전한 상태를 유지하는 것, 위험에 대해서 방호하는 것, 위험에 노출되지 않도록 하는 것
  - 100% 보안이란 없다. 위협 요소를 식별, 분석, 통제함으로서 불확실한 이벤트 발생 위험을 수습 가능한 수준으로 최소화 하는 것
- 위험(Risk) : 비인가된 접근, 사용, 노출, 파괴, 변경, 탐색, 조사, 기록 등의 행위가 발생할 가능성이나 그 징후

- 정보 보안 : 위험으로부터 정보와 정보 시스템을 보호하는 것.
  - 데이터의 형태나 위치에 상관 없이 데이터의 기밀성, 가용성, 무결성을 보호하는 데에 초점
- DB 보안 : DB와 DB 내 저장된 데이터를 비인가된 변경, 파괴, 노출 및 비일관성을 발생시키는 사건이나 위협으로부터 보호하는 것.
  - DB와 DB 내 저장된 데이터의 보호에 초점

- DB 보안을 위해 사용자 접근 이력, DB 작업 이력 등을 조회할 수 있어야 함



### 정보보안, DB 보안의 3요소

- 기밀성 : 선별적 접근 체계를 만들어 비인가된 개인이나 시스템에 의한 접근과 이에 따른 정보 공개 및 누출을 막는 것
  - 접근 제어
    - 데이터 분류 : 접근 가능한 데이터를 선별 해야 함
    - 접근권한 분류 : 접근할 수 있는 자격을 분류해야 함.
  - 암호화 : 중요한 내용을 암호화 함으로써 제3자가 내용을 획득하여도 알수 없도록 조치
- 무결성 : 정당한 방법에 의하지 않고는 데이터가 변경될 수 없음을 의미하며, 데이터의 정확성, 완전성을 보장하고 그 내용이 고의/악의로 변경되거나 훼손 또는 파괴되지 않음을 보장하는 것
  - 접근제어 : 사용자가 데이터 변경 권한이 있는지를 검증
  - 의미적 무결성 제약 : 갱신된 데이터가 의미적으로 정확한지를 검증. 데이터 훼손 검증을 위해 디지털 서명이 사용되기도 함.
    - 의미적 무결성 : 데이터 변경 시 허용된 범위의 데이터값으로 수정되도록 보장하여 수정될 데이터의 논 리적 일치성을 유지하는 것
  - 데이터 무결성 != DB에서의 참조 무결성 (RDB 관계모델에서 2개의 관련 있던 관계 변수(테이블) 간의 일관성)
- 가용성 : 정당한 권한을 가진 사용자나 애플리케이션에 대해 원하는 데이터에 대한 원활한 접근을 제공하는 서비스를 지속할 수 있도록 보장하는 것



### DB 보안 위협 요소

1. 위협 (Threats) : 시스템이 관리하는 정보를 유출 또는 수정하여 단위 조직 또는 전사 차원의 업무 목적 달성이나 미션 수행에 대해 예기치 못한 영향을 미치는 적대적 행위
   1. 데이터 노출
   2. 데이터의 부적절한 변경
   3. 서비스 거부 (DoS, Denial of Service)
2. 위험 (Risks) : 비인가된 접근, 사용, 노출, 파괴, 변경, 탐색, 조사, 기록 등의 행위가 발생할 가능성이나 그 징후
   1. 인가/비인가된 사용자나 해커 등에 의해 우발적 또는 고의적으로 발생하는 비인가된 활동이나 오용
      1. DB 내에 있는 민감한 데이터, 메타데이터(metadata)나 함수(functions)에 대한 부적절한 접근, 또는 DB 프로그램, DB운영이나 보안에 관련된 환경 설정 등에 대한 부적절한 변경 등
   2. 악성코드 감염
      1. 악성코드 : 사용자의 의사와 이익에 반해 시스템을 파괴하거나 정보를 유출하는 등의 악의적 활동을 수행하도록 제작된 소프트웨어.
   3. 고의적으로 인가된 사용자가 DB를 사용할 수 없도록 만드는 과부하, 성능 제약, 용량 문제 등
3. 취약점 (Vulnerability) : 운영체계나 시스템, 응용소프트웨어, DB 시스템 등이 지니고 있는 원래 형태 내 에서의 보안상의 문제점이나 허점
   1. 취약점 관리 : 취약점들을 식별하고(Identifying), 분류하여(Classifying), 개선하고 (Remediating), 완화시키는(Mitigating) 순환적 절차로 이루어지는 일련의 활동
   2. 취약점 제거 보안통제 방법으로는 접근제어, 감사, 인증, 암호화, 무결성 제어, 백업, 애플리케이션 보안 등이 존재
   3. 보안 컴플라이언스 : 정보보호를 위한 각종 법령이나 제도적 규제, 알려진 권고사항 등에 철저히 대응할 수 있도록 보안 통제를 구축하는 것



**보안 침해 경로 요약**

- 자연적 또는 인위적 DB 침해 : 천재지변, 시스템 장애, 데이터 파괴, 사용자 실수 등
- 관리 소홀로 인한 DB 침해 : 디폴트 DB 사용자 계정 유지, 추측하기 쉬운 패스워드 등
- 고의적 보안침해 : 불법 접근, 아이디 도용 등
- 유통 경로 : 보안 관리 결여된 문서 파일의 유통 등
- 프로그램 오류 : 실수 또는 의도된 프로그램 코딩으로 인한 DB 훼손
- 프로젝트 수행과정에서의 부득이한 DB 접근 허용
- 운영과정에서의 권한관리 소홀



### DB 보안 범위

- 보안 범위를 정의하는 목적 : 체계적이고 견고한 보안 구축, 책임소재를 분명히 하기 위함
- 보안 통제 : 보안 위험을 회피, 대응하거나 최소화하도록 하는 대응장치
  - 관리적 보안 통제 : 명문화되어 승인된 정책, 절차, 표준, 그리고 가이드라인 등으로 구성. 업무를 운영하고 인력을 관리하기 위한 프레임워크를 구성함으로써 구성원들이 업무 수행 방법과 일상적 운영 방 법 등을 알 수 있도록 하는 것
    - 예시 : 전사적 보안 정책, 비밀번호 정책, 시큐리티 데이....etc
  - 논리적(기술적) 보안 통제 : 정보와 정보시스템에 대한 접근을 감시하고 제어하기 위해 소프트웨어와 데이터를 사용하는 통제
    - 예시 :  비밀번호, 네트워크 및 호스트 기반 방화벽, 네트워크 침입 탐지 시스템, 접근제어목록, 데이터 암호화
    - 최소 권한의 원칙 : 개별 프로그램이나 시스템 프로세스가 필요 이상의 접근권한을 획득하는 것을 허용하지 않는 것.
  - 물리적 보안 통제 : 작업 장소의 환경과 컴퓨팅 장비들을 감시하고 통제하는 것
    - 예시 : 출입 통제 장치(도어락), 경보 장치, 감시 카메라 등

- 심층 방어 : 겹겹이 보안 수단을 중첩하여 구성하는 것을 말함. 
  - 네트워크 보안 - 서버 보안 - 어플리케이션 보안 - DB 보안 



**DB 보안 요구사항**

- 정당한 사용자의 데이터 접근 보장
- 추론 방지 : 기밀성이 없는 데이터로부터 기밀정보를 얻어낼 가능성을 방지하는 것. 
  - ex. 제갈 성씨를 가진 직원들의 평균 급여 조회 쿼리 실행 - 제갈 성씨 가진 직원이 딱 한 명밖에 없다면?
- 데이터의 무결성 유지
- 데이터의 의미적 무결성 유지
- 시스템 감사 지원 : 데이터 분류에 따라 중요 정보에 대한 접근 기록을 유지할 수 있어야 함
- 사용자 인증
- 기밀 데이터 관리와 보호
- 다단계 보호 : 보호 요구사항의 집합을 의미함.

이 요구사항을 하나하나 다 어떻게 보장을 할까? 



### DB 보안 프레임워크

DB 보안을 구축하는데 따른 효과적인 통제 수단과 이들 의 구축절차 및 주요 태스크 등을 일목요연하게 정리한 것.

보안의 3요소, 보안의 위협 요소, 보안 요구사항 등을 고려하여 통제 방법 사례를 정리하고, 보안 통제 방법으로 그룹화한다.

[DB 보안 프레임워크 표](https://dataonair.or.kr/publishing/img/knowledge/111221_dqc14.jpg)





