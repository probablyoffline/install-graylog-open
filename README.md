# install-graylog-open
Stand alone instance of graylog on Ubuntu. Note: CPU needs AVX instruction set.
<br>
Scripts created for lab and testing purposes.<br>
<br>
Security notes:<br>
web server is http after setup<br>
install-graylog-server.sh - temporary unencrypted 'secrets' files created.<br>
<br>
Ubuntu 22.04 Jammy<br>
OpenSearch 2.9.0<br>
MongoDB 7.0<br>
Graylog Open 5.1.5<br>
<br>
Important Files locations:<br>
MongoDB data directory /var/lib/mongodb<br>
MongoDB log direcotry /var/log/mongodb<br>
MongoDB configuration file /etc/mongod.conf<br>
<br>
OpenSearch<br>
OpenSearch config /graylog/opensearch/config/opensearch.yml<br>
OpenSearch logs /var/log/opensearch/graylog.log<br>
<br>
Graylog<br>
Graylog config /etc/graylog/server/server.conf<br>
Graylog log /var/log/graylog-server/server.log<br>
