# 🦞 OpenClaw Multi-Agent System

Sistema multi-agente hierárquico baseado em OpenClaw, pronto para deploy em VPS DigitalOcean com Supabase como Data Layer.

---

## Arquitetura — Hierarquia de Comando

```
Renaldo (CEO / Human)
└── Amora (L4 · Autonomous) — github-copilot/gpt-4o
    ├── Planner (L3 · Operator) — github-copilot/gpt-4o
    │   ├── Orchestrator (L2 · Advisor) — github-copilot/gpt-4o
    │   ├── Dev (L2 · Advisor) — github-copilot/gpt-4o
    │   └── QA (L2 · Advisor) — github-copilot/gpt-4o
    ├── Scraper (L1 · Observer) — github-copilot/gpt-4o
    └── Content (L1 · Observer) — github-copilot/gpt-4o
```

> **Comunicação** flui para **cima** (agente → supervisor).
> **Coordenação** flui para **baixo** via Amora.
> Agentes **não falam diretamente** entre si (por enquanto).

---

## Agentes

| Agente        | Nível | Papel      | Modelo                 | Heartbeat | Triggers                  |
|---------------|-------|------------|------------------------|-----------|---------------------------|
| Amora         | L4    | Autonomous | github-copilot/gpt-4o | 30min     | Telegram HQ + DM          |
| Planner       | L3    | Operator   | github-copilot/gpt-4o | Sob demanda | Telegram tópico 719     |
| Orchestrator  | L2    | Advisor    | github-copilot/gpt-4o | —         | Planner / Amora           |
| Dev           | L2    | Advisor    | github-copilot/gpt-4o | 10min*    | Planner / Amora           |
| QA            | L2    | Advisor    | github-copilot/gpt-4o | —         | Amora (spawned)           |
| Scraper       | L1    | Observer   | github-copilot/gpt-4o | —         | Amora                     |
| Content       | L1    | Observer   | github-copilot/gpt-4o | —         | Amora (spawned)           |

*futuro

---

## Pré-requisitos

- VPS Ubuntu 22.04 com **mínimo 4GB RAM** (ex: DigitalOcean Droplet)
- Domínio apontando para o IP da VPS
- Docker 24+ e Docker Compose v2
- Conta GitHub Copilot com API Key
- Contas Supabase, Telegram Bot, Discord Bot
- 1Password CLI instalado (`op`) — Regra #4

---

## Instalação

### 1. Instale o Docker e Docker Compose

> Pule este passo se já tiver o Docker instalado.

```bash
# Instalar dependências
sudo apt-get update
sudo apt-get install -y curl git

# Instalar Docker via script oficial
curl -fsSL https://get.docker.com | sudo sh

# Adicionar seu usuário ao grupo docker (evita usar sudo a cada comando)
sudo usermod -aG docker $USER
newgrp docker

# Verificar instalação
docker --version
docker compose version
```

### 2. Instale o 1Password CLI (Regra #4 — obrigatório)

```bash
# Ubuntu/Debian
curl -sS https://downloads.1password.com/linux/keys/1password.asc \
  | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] \
  https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" \
  | sudo tee /etc/apt/sources.list.d/1password.list

sudo apt-get update && sudo apt-get install -y 1password-cli

# Verificar instalação
op --version
```

### 3. Clone o repositório

```bash
git clone https://github.com/renaldodev/copenclaw-multi-agents.git
cd copenclaw-multi-agents
```

### 4. Configure as variáveis de ambiente

```bash
cp .env.example .env
nano .env
```

Preencha **todas** as variáveis obrigatórias:

| Variável                  | Como obter                                                      |
|---------------------------|-----------------------------------------------------------------|
| `GITHUB_COPILOT_API_KEY`  | [GitHub Settings → Copilot](https://github.com/settings/copilot) |
| `SUPABASE_DB_PASSWORD`    | Senha forte para o PostgreSQL local                             |
| `SUPABASE_ANON_KEY`       | Gerado pelo Supabase ou use `openssl rand -base64 32`           |
| `SUPABASE_SERVICE_KEY`    | Gerado pelo Supabase ou use `openssl rand -base64 32`           |
| `SUPABASE_URL`            | `http://localhost:8000` (padrão local)                          |
| `TELEGRAM_BOT_TOKEN`      | [@BotFather](https://t.me/BotFather) no Telegram               |
| `DISCORD_BOT_TOKEN`       | [Discord Developer Portal](https://discord.com/developers/applications) |
| `OP_SERVICE_ACCOUNT_TOKEN`| [1Password Service Account](https://developer.1password.com/docs/service-accounts/) |

### 5. Configure o nginx com seu domínio

```bash
# Substitua SEU_DOMINIO pelo seu domínio real (ex: openclaw.meusite.com)
sed -i 's/YOUR_DOMAIN_HERE/SEU_DOMINIO/g' nginx/conf.d/default.conf
```

Ou edite manualmente:

```bash
nano nginx/conf.d/default.conf
```

### 6. Gere o certificado SSL (Let's Encrypt)

> ⚠️ Antes de continuar, certifique-se de que a **porta 80 está aberta** no firewall:
> ```bash
> sudo ufw allow 80/tcp && sudo ufw allow 443/tcp
> ```

```bash
sudo apt-get install -y certbot
sudo certbot certonly --standalone -d SEU_DOMINIO \
  --email SEU_EMAIL --agree-tos --non-interactive
```

> Substitua `SEU_DOMINIO` pelo seu domínio (ex: `openclaw.meusite.com`) e `SEU_EMAIL` pelo seu e-mail real.

### 7. Suba os serviços

**Opção A — Script automático (recomendado para VPS nova):**

```bash
sudo bash setup-digitalocean.sh
```

**Opção B — Manualmente:**

```bash
# Baixar imagens
docker compose pull

# Subir todos os serviços em background
docker compose up -d

# Acompanhar logs em tempo real
docker compose logs -f
```

### 8. Verifique se tudo está rodando

```bash
# Listar containers e verificar status "Up"
docker compose ps

# Testar gateway OpenClaw
curl -s http://localhost:3000/health

# Testar Supabase API (PostgREST) — deve retornar JSON com os 7 agentes do seed
curl -s http://localhost:8000/agents
```

Resultado esperado: todos os containers com status **Up** e o endpoint `/agents` retornando os 7 agentes do seed.

### 9. Acesse o sistema

| Serviço          | URL                              |
|------------------|----------------------------------|
| OpenClaw Gateway | `https://seu-dominio.com`        |
| OpenClaw UI      | `https://seu-dominio.com:4000`   |
| Supabase API     | `https://seu-dominio.com/supabase/` |

---

### Comandos úteis pós-instalação

```bash
# Parar todos os serviços
docker compose down

# Reiniciar um serviço específico
docker compose restart openclaw

# Ver logs de um serviço específico
docker compose logs -f openclaw

# Atualizar para nova versão
git pull
docker compose pull
docker compose up -d

# Acessar o banco de dados
docker compose exec supabase-db psql -U postgres -d postgres
```

---

## Estrutura de Arquivos

```
copenclaw-multi-agents/
├── openclaw.json              # Configuração principal dos agentes
├── docker-compose.yml         # Orquestração dos serviços
├── .env.example               # Template de variáveis de ambiente
├── setup-digitalocean.sh      # Script de setup para VPS Ubuntu
├── supabase/
│   └── init.sql               # Schema completo do banco de dados
├── nginx/
│   └── conf.d/
│       └── default.conf       # Configuração do reverse proxy
├── shared/
│   ├── TEAM.md                # Org chart vivo (lido por todos os agentes)
│   ├── RULES.md               # 10 Regras Invioláveis
│   └── lessons/               # Lições aprendidas por agente (Regra #9)
└── workspaces/
    ├── amora/
    │   ├── SOUL.md            # Identidade, valores e guardrails
    │   └── WORKING.md         # Contexto atual da task
    ├── planner/
    ├── orchestrator/
    ├── dev/
    ├── qa/
    ├── scraper/
    └── content/
```

---

## Task Lifecycle

```
Backlog → Assign → Doing → Review → Done
                                      ↕
                                   Blocked
```

- Tasks vivem no **Mission Control** (Supabase)
- Agentes recebem contexto via `WORKING.md` + API `/context`
- Resultado volta como **comentário no card** (Regra #8)

---

## Performance Review (Semanal — Domingos)

Amora avalia cada agente com os critérios:

| Critério         | Peso |
|------------------|------|
| Quality Score    | ⭐⭐⭐ |
| Velocidade       | ⭐⭐   |
| Proatividade     | ⭐⭐   |
| Aderência        | ⭐⭐⭐ |
| Custo-Benefício  | ⭐⭐   |

**Decisão possível**: ⬆️ Promover | 🟰 Manter | ⬇️ Rebaixar | ❌ Desativar

Registro em `shared/TEAM.md` + `shared/lessons/{agent}.md`

---

## 10 Regras Invioláveis

1. **Texto > Cérebro** — Se importa, escreve no arquivo. "Mental notes" morrem no restart.
2. **Todo agente começa L1** — Sem exceções. Confiança se conquista, não se assume.
3. **SOUL.md define quem o agente É** — Sem alma, é só um chatbot.
4. **Nunca hardcodar credenciais** — Tudo via 1Password CLI (`op item get`).
5. **Dado privado não vaza** — Nunca em grupos, nunca sem permissão.
6. **Um agente com 8 skills > 8 agentes** — Só cria agente novo quando skill não resolve.
7. **shared/TEAM.md é obrigatório** — Todo agente lê na sessão.
8. **Resultado volta como comentário no card** — MC (Supabase) é source of truth.
9. **Lição aprendida → shared/lessons/** — Erro que não vira lição vai se repetir.
10. **Se travou, bloqueia e comenta** — Mover card pra "blocked" + explicar o motivo.

---

## API Endpoints

| Endpoint                        | Descrição                            |
|---------------------------------|--------------------------------------|
| `GET /cards`                    | Listar cards do Mission Control      |
| `GET /tasks`                    | Listar tasks                         |
| `GET /bookmarks`                | Listar bookmarks                     |
| `GET /activity`                 | Feed de atividades                   |
| `GET /notifications`            | Notificações                         |
| `GET /sessions`                 | Sessões ativas                       |
| `GET /memory`                   | Memória compartilhada                |
| `GET /agents/{id}/context`      | Contexto do agente                   |
| `POST /agents/{id}/assign-task` | Atribuir task ao agente              |
| `POST /agents/{id}/complete-task` | Marcar task como concluída         |

---

## Sistema de Níveis

| Nível | Nome      | Autonomia                                              |
|-------|-----------|--------------------------------------------------------|
| L1    | Observer  | Executa tasks atribuídas, output revisado              |
| L2    | Advisor   | Recomenda e executa com aprovação, pode sugerir        |
| L3    | Operator  | Executa autônomo dentro dos guardrails                 |
| L4    | Autonomous| Autoridade total no domínio, reporta direto ao Renaldo |

---

## Links Úteis

- [OpenClaw Docs](https://openclaw.dev/docs)
- [Supabase Docs](https://supabase.com/docs)
- [Docker Compose Docs](https://docs.docker.com/compose/)
- [DigitalOcean — Create Droplet](https://docs.digitalocean.com/products/droplets/how-to/create/)

---

> **Renaldo** (CEO/Human) é o topo da cadeia de comando.
> **Amora** é a coordenadora — único ponto de contato direto com o Renaldo no sistema.
