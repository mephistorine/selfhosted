```bash
ansible all -i ./inventory.ini -u root -m 'ping'
```

```bash
ansible-playbook playbook.yml -i inventory.ini
```

```bash
ansible-vault edit group_vars/all/vault.yml
```

```text
caddy:
    container_name: caddy
    image: caddy:2.8.4@sha256:60199fbf2046892e0aa4b19c7d3adf71f530c36abc65728627422148a75b3475
    restart: unless-stopped
    ports:
      - 80:80
      - 443:443
      - 443:443/udp
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./caddy_data:/data
      - ./caddy_config:/config
    depends_on:
      - plausible_db
      - plausible_events_db
      - plausible
    networks:
      - caddy_net

  pocketbase:
    container_name: pocketbase
    image: elestio/pocketbase:v0.22.13@sha256:e11e46dbe72385084a5a2087972358653592c9d38e037d85cb16e063463c79e3
    restart: unless-stopped
    ports:
      - 8001:8090
    volumes:
      - ./pocketbase:/pb_data
    healthcheck:
      test: wget --no-verbose --tries=1 --spider http://localhost:8090/api/health || exit 1
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - mephi

  imgproxy:
    container_name: imgproxy
    image: darthsim/imgproxy:v3.24.1@sha256:360e3b460816d06ecdeb7141999fa28fcb59c085e50af86b2f57bc7eb0c40f18
    restart: unless-stopped
    ports:
      - 9000:8080
    healthcheck:
      test: [ "CMD", "imgproxy", "health" ]
      timeout: 10s
      interval: 10s
      retries: 3
    networks:
      - mephi

  bitwarden:
    container_name: bitwarden
    image: bitwarden/self-host:2024.5.0-beta@sha256:82dd3318e3483492364c09a27819f6c14753e9bb721a4d81cf9c624b99057407
    restart: unless-stopped
    ports:
      - 9001:8080
    volumes:
      - ./bitwarden:/etc/bitwarden
    depends_on:
      - bitwarden_db
    networks:
      - mephi
    environment:
      - BW_DOMAIN=bitwarden.mephi.dev
      - BW_DB_PROVIDER=postgresql
      - BW_DB_SERVER=db
      - BW_DB_DATABASE={{BW_DB_DATABASE}}
      - BW_DB_USERNAME={{BW_DB_USERNAME}}
      - BW_DB_PASSWORD={{BW_DB_PASSWORD}}

  bitwarden_db:
    container_name: bitwarden_db
    image: postgres:16.3-alpine3.20@sha256:d037653693c4168efbb95cdc1db705d31278a4a8d608d133eca1f07af9793960
    restart: always
    environment:
      - POSTGRES_DB={{BW_DB_DATABASE}}
      - POSTGRES_USER={{BW_DB_USERNAME}}
      - POSTGRES_PASSWORD={{BW_DB_PASSWORD}}
    ports:
      - 8002:5432
    networks:
      - mephi
    volumes:
      - ./bitwarden_db:/var/lib/postgresql/data

  plausible_db:
    container_name: plausible_db
    image: postgres:16.3-alpine3.20@sha256:d037653693c4168efbb95cdc1db705d31278a4a8d608d133eca1f07af9793960
    restart: always
    ports:
      - 8003:5432
    volumes:
      - ./plausible_db:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=plausible_db
      - POSTGRES_PASSWORD={{PL_DB_PASSWORD}}
    networks:
      - mephi

  plausible_events_db:
    container_name: plausible_events_db
    image: clickhouse/clickhouse-server:23.3.7.5-alpine@sha256:f226fe41f0578968b7f68a54b902d203ff4decfddfccb97c89fe5bfc36a51b66
    restart: always
    ports:
      - 8004:8123
    volumes:
      - ./plausible_event-data:/var/lib/clickhouse
      - ./plausible_event-logs:/var/log/clickhouse-server
      - ./plausible-clickhouse/clickhouse-config.xml:/etc/clickhouse-server/config.d/logging.xml:ro
      - ./plausible-clickhouse/clickhouse-user-config.xml:/etc/clickhouse-server/users.d/logging.xml:ro
    ulimits:
      nofile:
        soft: 262144
        hard: 262144
    networks:
      - mephi

  plausible:
    container_name: plausible
    image: plausible/analytics:v2.0@sha256:cd5f75e1399073669b13b4151cc603332a825324d0b8f13dfc9de9112a3c68a1
    restart: always
    command: sh -c "sleep 10 && /entrypoint.sh db createdb && /entrypoint.sh db migrate && /entrypoint.sh run"
    depends_on:
      - plausible_db
      - plausible_events_db
    ports:
      - 9003:8000
    environment:
      - BASE_URL=plausible.mephi.dev
      - SECRET_KEY_BASE={{PL_SECRET_KEY_BASE}}
      - TOTP_VAULT_KEY={{PL_TOTP_VAULT_KEY}}
      - DATABASE_URL=postgres://postgres:{{PL_DB_PASSWORD}}@plausible_db:8003/plausible_db
      - CLICKHOUSE_DATABASE_URL=http://plausible_events_db:8004/plausible_events_db
    networks:
      - mephi

  nextcloud_db:
    container_name: nextcloud_db
    image: mariadb:10.6
    restart: always
    command: --transaction-isolation=READ-COMMITTED --log-bin=binlog --binlog-format=ROW
    volumes:
      - ./nextcloud_db:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=
      - MYSQL_PASSWORD={{NC_DB_PASSWORD}}
      - MYSQL_DATABASE={{NC_DB_NAME}}
      - MYSQL_USER={{NC_DB_USERNAME}}

  nextcloud:
    container_name: nextcloud
    image: nextcloud
    restart: always
    ports:
      - 9005:80
    links:
      - "nextcloud_db:db"
    volumes:
      - ./nextcloud:/var/www/html
    environment:
      - MYSQL_PASSWORD={{NC_DB_PASSWORD}}
      - MYSQL_DATABASE={{NC_DB_NAME}}
      - MYSQL_USER={{NC_DB_USERNAME}}
      - MYSQL_HOST=db
      - NEXTCLOUD_ADMIN_USER={{USERNAME}}
      - NEXTCLOUD_ADMIN_PASSWORD={{NC_ADMIN_PASSWORD}}
      - OBJECTSTORE_S3_BUCKET=mephi-nextcloud
      - OBJECTSTORE_S3_REGION=ru-central1
      - OBJECTSTORE_S3_HOST=storage.yandexcloud.net
      - OBJECTSTORE_S3_PORT=80
      - OBJECTSTORE_S3_KEY={{NC_S3_KEY}}
      - OBJECTSTORE_S3_SECRET={{NC_S3_SECRET}}
      - OBJECTSTORE_S3_STORAGE_CLASS=STANDARD



```
