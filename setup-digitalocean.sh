#!/usr/bin/env bash
# =============================================================================
# setup-digitalocean.sh — Setup OpenClaw Multi-Agent em VPS Ubuntu (DigitalOcean)
# =============================================================================
# Uso: sudo bash setup-digitalocean.sh
# Requisitos: Ubuntu 22.04 LTS, 4GB RAM mínimo, domínio apontando para o IP da VPS
# =============================================================================

set -euo pipefail

REPO_URL="https://github.com/renaldodev/copenclaw-multi-agents.git"
APP_DIR="/opt/copenclaw-multi-agents"

echo "========================================"
echo "  🦞 OpenClaw — Setup DigitalOcean VPS"
echo "========================================"
echo ""

# ----------------------------------------------------------------------------
# 1. Atualizar sistema
# ----------------------------------------------------------------------------
echo "[1/8] Atualizando sistema..."
apt-get update -y
apt-get upgrade -y
apt-get install -y curl git ufw certbot python3-certbot-nginx

# ----------------------------------------------------------------------------
# 2. Instalar Docker
# ----------------------------------------------------------------------------
echo "[2/8] Instalando Docker..."
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
fi

# Instalar Docker Compose v2
if ! docker compose version &>/dev/null; then
  apt-get install -y docker-compose-plugin
fi

echo "  Docker: $(docker --version)"
echo "  Docker Compose: $(docker compose version)"

# ----------------------------------------------------------------------------
# 3. Configurar UFW (Firewall)
# ----------------------------------------------------------------------------
echo "[3/8] Configurando firewall (UFW)..."
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
ufw status

# ----------------------------------------------------------------------------
# 4. Clonar repositório
# ----------------------------------------------------------------------------
echo "[4/8] Clonando repositório..."
if [ -d "$APP_DIR" ]; then
  echo "  Diretório já existe. Fazendo git pull..."
  git -C "$APP_DIR" pull
else
  git clone "$REPO_URL" "$APP_DIR"
fi
cd "$APP_DIR"

# ----------------------------------------------------------------------------
# 5. Criar diretórios dos workspaces
# ----------------------------------------------------------------------------
echo "[5/8] Criando diretórios dos workspaces..."
for agent in amora planner orchestrator dev qa scraper content; do
  mkdir -p "workspaces/$agent"
done
mkdir -p shared/lessons nginx/conf.d supabase

# ----------------------------------------------------------------------------
# 6. Configurar .env
# ----------------------------------------------------------------------------
echo "[6/8] Configurando variáveis de ambiente..."
if [ ! -f ".env" ]; then
  cp .env.example .env
  echo ""
  echo "  ⚠️  AÇÃO NECESSÁRIA:"
  echo "  Edite o arquivo .env com suas credenciais reais:"
  echo "    nano $APP_DIR/.env"
  echo ""
  echo "  Variáveis obrigatórias:"
  echo "    - GITHUB_COPILOT_API_KEY"
  echo "    - SUPABASE_DB_PASSWORD"
  echo "    - SUPABASE_ANON_KEY"
  echo "    - SUPABASE_SERVICE_KEY"
  echo "    - TELEGRAM_BOT_TOKEN"
  echo "    - DISCORD_BOT_TOKEN"
  echo "    - OP_SERVICE_ACCOUNT_TOKEN"
  echo ""
  read -r -p "  Pressione ENTER após configurar o .env para continuar..." _
else
  echo "  .env já existe, pulando..."
fi

# ----------------------------------------------------------------------------
# 7. SSL com Certbot (opcional)
# ----------------------------------------------------------------------------
echo "[7/8] Configurando SSL (Certbot)..."
read -r -p "  Deseja configurar SSL agora? (s/N): " ssl_response
if [[ "$ssl_response" =~ ^[Ss]$ ]]; then
  read -r -p "  Informe seu domínio (ex: openclaw.seudominio.com): " domain
  read -r -p "  Informe seu e-mail para o Certbot: " email
  certbot certonly --nginx -d "$domain" --email "$email" --agree-tos --non-interactive
  echo "  SSL configurado para: $domain"
  echo "  Atualize nginx/conf.d/default.conf com seu domínio."
else
  echo "  SSL pulado. Configure manualmente depois se necessário."
fi

# ----------------------------------------------------------------------------
# 8. Subir serviços com Docker Compose
# ----------------------------------------------------------------------------
echo "[8/8] Subindo serviços com Docker Compose..."
docker compose pull
docker compose up -d

echo ""
echo "========================================"
echo "  ✅ Setup concluído!"
echo "========================================"
echo ""
echo "  🌐 URLs de acesso:"
echo "    Gateway OpenClaw : http://$(curl -s ifconfig.me):3000"
echo "    UI OpenClaw      : http://$(curl -s ifconfig.me):4000"
echo "    Supabase API     : http://$(curl -s ifconfig.me):8000"
echo ""
echo "  📋 Comandos úteis:"
echo "    Ver logs         : docker compose logs -f"
echo "    Parar serviços   : docker compose down"
echo "    Reiniciar        : docker compose restart"
echo ""
echo "  📁 Diretório da aplicação: $APP_DIR"
echo ""
