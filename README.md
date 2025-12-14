# PostgreSQL + pgBackRest (Docker Compose)

Esta documentação descreve a configuração e o uso do **PostgreSQL 18** com **pgBackRest** para backup e restore em ambiente Docker, conforme definido no `docker-compose.yml`.

---

## 📦 Serviço PostgreSQL

```yaml
services:
  postgres-db:
    build: .
    container_name: postgres-db
    restart: unless-stopped
    networks:
      - internal
    ports:
      - "127.0.0.1:5432:5432"
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
      TZ: America/Sao_Paulo
      PGDATA: /var/lib/postgresql/18/docker
      PGBACKREST_PG1_PATH: /var/lib/postgresql/18/docker
      PGBACKREST_STANZA: main
      PGBACKREST_REPO1_TYPE: posix
      PGBACKREST_REPO1_PATH: /bkp
      PGBACKREST_RETENTION_FULL: "2"
      PGBACKREST_RETENTION_DIFF: "7"
    secrets:
      - postgres_password
    volumes:
      - pg_data:/var/lib/postgresql
      - ./pgbackrest_repo:/bkp
```

---

## 🧱 Arquitetura

- PostgreSQL 18 rodando em container Docker
- pgBackRest instalado no mesmo container
- Dados do banco em volume persistente (`pg_data`)
- Repositório de backup local (posix) em diretório montado (`./pgbackrest_repo`)
- Comunicação restrita à rede Docker interna

---

## 📂 Diretórios importantes

| Item                   | Caminho                         |
| ---------------------- | ------------------------------- |
| PGDATA                 | `/var/lib/postgresql/18/docker` |
| Dados PostgreSQL       | `/var/lib/postgresql`           |
| Repositório pgBackRest | `/bkp`                          |
| WAL archive            | `/bkp/archive/main`             |
| Backups                | `/bkp/backup/main`              |

---

## 🔐 Secrets

A senha do PostgreSQL é carregada via Docker Secrets:

```yaml
secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt
```

A variável utilizada pelo container é:

```env
POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password
```

Isso evita exposição de senha em texto plano.

---

## ♻️ Política de retenção de backups

```env
PGBACKREST_RETENTION_FULL=2
PGBACKREST_RETENTION_DIFF=7
```

### Significado

- Mantém **apenas os 2 backups FULL mais recentes**
- Para cada FULL, mantém **até 7 backups diferenciais**
- Backups mais antigos são removidos automaticamente via `expire`

Quando um FULL expira, todos os DIFF/INCR dependentes também são removidos.

---

## 🔄 WAL Archiving (obrigatório)

O PostgreSQL deve estar configurado com:

```sql
archive_mode = on
archive_command = 'pgbackrest --stanza=main archive-push %p'
wal_level = replica
```

Esses parâmetros garantem consistência dos backups e permitem restore completo ou PITR.

---

## 🏗️ Inicialização do pgBackRest

Executar apenas uma vez:

```bash
docker exec -u postgres -it postgres-db pgbackrest --stanza=main stanza-create
```

---

## 💾 Execução de backups

### Backup FULL (primeiro backup)

```bash
docker exec -u postgres -it postgres-db pgbackrest --stanza=main --type=full backup
```

### Backup diferencial

```bash
docker exec -u postgres -it postgres-db pgbackrest --stanza=main --type=diff backup
```

### Backup incremental

```bash
docker exec -u postgres -it postgres-db pgbackrest --stanza=main --type=incr backup
```

---

## 📊 Status dos backups

```bash
docker exec -u postgres -it postgres-db pgbackrest --stanza=main info
```

---

## 🔎 Verificação de integridade

```bash
docker exec -u postgres -it postgres-db pgbackrest --stanza=main verify
```

Resultado esperado:

```
verify command end: completed successfully
```

---

## 🧪 Teste de restore (recomendado)

Restore para diretório alternativo:

```bash
docker exec -it postgres-db bash -lc '
rm -rf /tmp/pg-restore-test
mkdir -p /tmp/pg-restore-test
chown -R postgres:postgres /tmp/pg-restore-test
'
```

```bash
docker exec -u postgres -it postgres-db pgbackrest --stanza=main --pg1-path=/tmp/pg-restore-test restore
```

Validação:

```bash
test -f /tmp/pg-restore-test/PG_VERSION && echo RESTORE_OK
```

---

## ❤️ Healthcheck

O container é monitorado via:

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
```

---

## ✅ Checklist de produção

- [x] WAL archiving habilitado
- [x] Stanza criada
- [x] Backup FULL executado
- [x] Verify executado com sucesso
- [x] Restore de teste validado

---

## 📌 Referências

- https://pgbackrest.org
- https://www.postgresql.org/docs/current/continuous-archiving.html
