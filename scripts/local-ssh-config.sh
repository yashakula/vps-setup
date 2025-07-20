#!/bin/bash

# Local SSH Configuration Helper Script
# Run this on your LOCAL machine after VPS setup

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    Local SSH Configuration Helper${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Get user input
read -p "Enter VPS IP address: " VPS_IP
while [[ -z "$VPS_IP" ]]; do
    read -p "IP address cannot be empty. Enter VPS IP: " VPS_IP
done

read -p "Enter VPS username: " VPS_USER
while [[ -z "$VPS_USER" ]]; do
    read -p "Username cannot be empty. Enter VPS username: " VPS_USER
done

read -p "Enter SSH port: " SSH_PORT
while [[ ! "$SSH_PORT" =~ ^[0-9]+$ ]]; do
    read -p "Invalid port. Enter SSH port: " SSH_PORT
done

read -p "Enter alias for this VPS (e.g., 'myserver'): " VPS_ALIAS
while [[ -z "$VPS_ALIAS" ]]; do
    read -p "Alias cannot be empty. Enter alias: " VPS_ALIAS
done

echo
log "Configuration:"
log "  VPS IP: $VPS_IP"
log "  Username: $VPS_USER"
log "  Port: $SSH_PORT"
log "  Alias: $VPS_ALIAS"
echo

# Ask user about key preference
echo
read -p "Use custom SSH key location? (y/N): " USE_CUSTOM_KEY

if [[ "$USE_CUSTOM_KEY" =~ ^[Yy]$ ]]; then
    read -p "Enter custom key name (e.g., my_vps_key): " CUSTOM_KEY_NAME
    while [[ -z "$CUSTOM_KEY_NAME" ]]; do
        read -p "Key name cannot be empty. Enter key name: " CUSTOM_KEY_NAME
    done
    SSH_KEY="$HOME/.ssh/$CUSTOM_KEY_NAME"
    SSH_KEY_PUB="$SSH_KEY.pub"
else
    SSH_KEY="$HOME/.ssh/id_ed25519"
    SSH_KEY_PUB="$SSH_KEY.pub"
fi

# Check if SSH key exists
if [[ ! -f "$SSH_KEY" ]]; then
    warn "Ed25519 SSH key not found at $SSH_KEY"
    read -p "Generate new Ed25519 SSH key? (y/N): " GENERATE_KEY
    if [[ "$GENERATE_KEY" =~ ^[Yy]$ ]]; then
        read -p "Enter your email: " EMAIL
        log "Generating Ed25519 SSH key..."
        if [[ "$USE_CUSTOM_KEY" =~ ^[Yy]$ ]]; then
            ssh-keygen -t ed25519 -f "$SSH_KEY" -C "$EMAIL"
        else
            ssh-keygen -t ed25519 -C "$EMAIL"
        fi
        log "Ed25519 SSH key generated at $SSH_KEY"
    else
        warn "Please generate an Ed25519 SSH key first:"
        if [[ "$USE_CUSTOM_KEY" =~ ^[Yy]$ ]]; then
            warn "  ssh-keygen -t ed25519 -f $SSH_KEY -C \"your_email@domain.com\""
        else
            warn "  ssh-keygen -t ed25519 -C \"your_email@domain.com\""
        fi
        exit 1
    fi
fi

# Create SSH config entry
SSH_CONFIG="$HOME/.ssh/config"
log "Adding entry to $SSH_CONFIG..."

# Backup existing config
if [[ -f "$SSH_CONFIG" ]]; then
    cp "$SSH_CONFIG" "$SSH_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    log "Backed up existing SSH config"
fi

# Create config directory if it doesn't exist
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Add new host entry
cat >> "$SSH_CONFIG" << EOF

Host $VPS_ALIAS
    HostName $VPS_IP
    User $VPS_USER
    Port $SSH_PORT
    IdentityFile $SSH_KEY
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF

chmod 600 "$SSH_CONFIG"

log "SSH config entry added for '$VPS_ALIAS'"

# Copy SSH key to VPS
log "Copying SSH public key to VPS..."
if command -v ssh-copy-id &> /dev/null; then
    if [[ "$USE_CUSTOM_KEY" =~ ^[Yy]$ ]]; then
        if ssh-copy-id -i "$SSH_KEY_PUB" -p "$SSH_PORT" "$VPS_USER@$VPS_IP"; then
            log "SSH key successfully copied to VPS"
        else
            warn "ssh-copy-id failed. You may need to copy the key manually."
            echo
            log "Your public key:"
            cat "$SSH_KEY_PUB"
            echo
            warn "Copy the above key and add it to ~/.ssh/authorized_keys on your VPS"
        fi
    else
        if ssh-copy-id -p "$SSH_PORT" "$VPS_USER@$VPS_IP"; then
            log "SSH key successfully copied to VPS"
        else
            warn "ssh-copy-id failed. You may need to copy the key manually."
            echo
            log "Your public key:"
            cat "$SSH_KEY_PUB"
            echo
            warn "Copy the above key and add it to ~/.ssh/authorized_keys on your VPS"
        fi
    fi
else
    warn "ssh-copy-id not available. Please copy your key manually:"
    echo
    log "Your public key:"
    cat "$SSH_KEY_PUB"
    echo
    warn "Add this key to ~/.ssh/authorized_keys on your VPS"
fi

echo
log "Testing SSH connection..."
if ssh -o ConnectTimeout=10 -o BatchMode=yes "$VPS_ALIAS" "echo 'SSH connection successful!'" 2>/dev/null; then
    log "✓ SSH connection test successful!"
else
    warn "SSH connection test failed. Please check:"
    warn "  1. VPS is running and accessible"
    warn "  2. SSH service is running on port $SSH_PORT"
    warn "  3. Firewall allows port $SSH_PORT"
    warn "  4. SSH key is properly configured"
fi

echo
log "Setup complete! You can now connect using:"
log "  ssh $VPS_ALIAS"
echo
log "Useful commands:"
log "  ssh $VPS_ALIAS                    # Connect to VPS"
log "  scp file.txt $VPS_ALIAS:~/        # Copy file to VPS"
log "  ssh $VPS_ALIAS 'command'          # Run remote command"
if [[ "$USE_CUSTOM_KEY" =~ ^[Yy]$ ]]; then
    echo
    log "Manual connection (without config file):"
    log "  ssh -i $SSH_KEY -p $SSH_PORT $VPS_USER@$VPS_IP"
fi
echo
warn "Remember to test the connection before closing your current session!"