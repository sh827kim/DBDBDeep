FROM centos:8

RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Linux-*
RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-Linux-*
RUN dnf install -y glibc-langpack-en sudo net-tools wget unzip
RUN dnf install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm -y
RUN dnf -qy module disable postgresql
RUN dnf install -y postgresql14-server
RUN mkdir -p /pgconf
RUN mkdir -p /mnt/server/archivedir


EXPOSE 5432

COPY ./pg_initialize.sh .
COPY ./pg_hba.conf /pgconf/
COPY ./postgresql.conf /pgconf/


ENTRYPOINT ["/sbin/init"]

