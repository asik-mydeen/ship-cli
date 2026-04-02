#!/usr/bin/env bash
# Quick setup script for ship CLI on a new machine
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

echo -e "${BOLD}${CYAN}═══ ship CLI Setup ═══${NC}\n"

INSTALL_DIR="$HOME/.autodeploy"

# 1. Copy files
echo -e "${BOLD}[1/4] Installing to $INSTALL_DIR${NC}"
mkdir -p "$INSTALL_DIR"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/ship" "$INSTALL_DIR/ship"
chmod +x "$INSTALL_DIR/ship"
echo -e "${GREEN}✔${NC} ship script installed"

# 2. Symlink to PATH
echo -e "\n${BOLD}[2/4] Adding to PATH${NC}"
if [[ -d /usr/local/bin ]] && [[ -w /usr/local/bin ]]; then
  ln -sf "$INSTALL_DIR/ship" /usr/local/bin/ship
  echo -e "${GREEN}✔${NC} Linked to /usr/local/bin/ship"
else
  mkdir -p "$HOME/.local/bin"
  ln -sf "$INSTALL_DIR/ship" "$HOME/.local/bin/ship"
  echo -e "${GREEN}✔${NC} Linked to ~/.local/bin/ship"
  if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo -e "${DIM}  Add this to your shell profile:${NC}"
    echo '  export PATH="$HOME/.local/bin:$PATH"'
  fi
fi

# 3. Create config files from examples if they don't exist
echo -e "\n${BOLD}[3/4] Config files${NC}"
if [[ ! -f "$INSTALL_DIR/.env" ]]; then
  cp "$SCRIPT_DIR/.env.example" "$INSTALL_DIR/.env"
  echo -e "${GREEN}✔${NC} Created $INSTALL_DIR/.env ${DIM}(edit with your secrets)${NC}"
else
  echo -e "${DIM}  .env already exists, skipping${NC}"
fi

if [[ ! -f "$INSTALL_DIR/.env.infra" ]]; then
  cp "$SCRIPT_DIR/.env.infra.example" "$INSTALL_DIR/.env.infra"
  echo -e "${GREEN}✔${NC} Created $INSTALL_DIR/.env.infra ${DIM}(edit with your infrastructure config)${NC}"
else
  echo -e "${DIM}  .env.infra already exists, skipping${NC}"
fi

# 4. Check Python dependency
echo -e "\n${BOLD}[4/4] Checking dependencies${NC}"
if python3 -c "import nacl" 2>/dev/null; then
  echo -e "${GREEN}✔${NC} pynacl installed"
else
  echo -e "${RED}✘${NC} pynacl not found — installing..."
  pip3 install pynacl -q && echo -e "${GREEN}✔${NC} pynacl installed" || echo -e "${RED}✘${NC} Failed to install pynacl. Run: pip3 install pynacl"
fi

echo -e "\n${BOLD}${GREEN}Done!${NC}\n"
echo -e "Next steps:"
echo -e "  1. Edit ${BOLD}$INSTALL_DIR/.env${NC} with your GitHub PAT and Cloudflare credentials"
echo -e "  2. Edit ${BOLD}$INSTALL_DIR/.env.infra${NC} with your Dokploy/Supabase/domain config"
echo -e "  3. Run ${BOLD}ship${NC} to verify"
echo -e "  4. Run ${BOLD}ship new${NC} to create your first project"
echo ""
