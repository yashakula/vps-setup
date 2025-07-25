# VPS Security Setup Guide

A quick guide to securely configure a fresh VPS with proper user management, SSH hardening, and firewall configuration.

## Prerequisites

- Fresh Ubuntu/Debian VPS
- Root access via SSH
- SSH client on your local machine

> 💡 **Security Audit Tool**: After completing this setup, consider running [vps-audit](https://github.com/vernu/vps-audit) to verify your VPS security configuration and identify any remaining vulnerabilities.

> ⚠️ **EXPERIMENTAL SCRIPTS WARNING**: The automation scripts in the `scripts/` directory are experimental and may not work correctly on all systems. Always review and test scripts on non-production systems first. Manual setup following the step-by-step instructions below is recommended for production environments.

## Step 1: Create Non-Root User with Sudo Privileges

**Connect as root:**

```bash
ssh root@your_server_ip
```

**Create new user:**

```bash
adduser username
usermod -aG sudo username
```

**Test sudo access:**

```bash
su - username
sudo whoami  # Should return 'root'
```

## Step 2: Generate and Configure SSH Keys

**On your local machine, generate SSH key pair:**

```bash
ssh-keygen -t ed25519 -C "your_email@domain.com"
# Save to default location: ~/.ssh/id_ed25519
# Use a strong passphrase
```

**For custom key location (optional):**

```bash
# Generate key with custom name/location
ssh-keygen -t ed25519 -f ~/.ssh/my_vps_key -C "your_email@domain.com"
# This creates:
# ~/.ssh/my_vps_key (private key)
# ~/.ssh/my_vps_key.pub (public key)
```

**Copy public key to VPS:**

```bash
# Using default key
ssh-copy-id username@your_server_ip

# Using custom key location
ssh-copy-id -i ~/.ssh/my_vps_key.pub username@your_server_ip
```

**Alternatively, manual setup on VPS:**

```bash
# On VPS as your user
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Display your public key on local machine
cat ~/.ssh/id_ed25519.pub
# OR for custom key: cat ~/.ssh/my_vps_key.pub

# Paste the public key content into authorized_keys on VPS
nano ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

**Test key authentication:**

```bash
ssh username@your_server_ip
```

## Step 3: Harden SSH Configuration

**Backup original SSH config:**

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
```

**Edit SSH configuration:**

```bash
sudo nano /etc/ssh/sshd_config
```

**Apply these security settings:**

```bash
# Change default port (choose between 1024-65535)
Port 2222

# Disable root login
PermitRootLogin no

# Disable password authentication
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no

# Enable public key authentication
PubkeyAuthentication yes

# Additional security (optional)
Protocol 2
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers username  # Replace with your username
```

**Test configuration and restart SSH:**

```bash
sudo sshd -t  # Test config syntax
sudo systemctl restart ssh

# If restart fails, try:
sudo systemctl daemon-reload
sudo systemctl restart ssh.socket
```

## Step 4: Update Local SSH Config

**Create/edit ~/.ssh/config on your local machine:**

```bash
# Using default key
Host vps
    HostName your_server_ip
    User username
    Port 2222
    IdentityFile ~/.ssh/id_ed25519

# Using custom key location
Host vps-custom
    HostName your_server_ip
    User username
    Port 2222
    IdentityFile ~/.ssh/my_vps_key
```

**Test connection with new config:**

```bash
# Using default key config
ssh vps

# Using custom key config
ssh vps-custom

# Or specify key manually without config file
ssh -i ~/.ssh/my_vps_key -p 2222 username@your_server_ip
```

## Step 5: Configure UFW Firewall

**Install and configure UFW:**

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH on custom port FIRST (critical!)
sudo ufw allow 2222/tcp   # SSH (secure shell access)

# Allow common services
sudo ufw allow 80/tcp     # HTTP (web traffic)
sudo ufw allow 443/tcp    # HTTPS (secure web traffic)
# sudo ufw allow 25/tcp   # SMTP (email sending) - uncomment if needed
# sudo ufw allow 587/tcp  # SMTP submission (secure email) - uncomment if needed
# sudo ufw allow 993/tcp  # IMAPS (secure IMAP email) - uncomment if needed
# sudo ufw allow 995/tcp  # POP3S (secure POP3 email) - uncomment if needed
# sudo ufw allow 53/udp   # DNS (if running DNS server) - uncomment if needed
# sudo ufw allow 123/udp  # NTP (time synchronization) - uncomment if needed

# Check status
sudo ufw status verbose

# View numbered rules (useful for deletion)
sudo ufw status numbered
# Example output:
#      To                         Action      From
#      --                         ------      ----
# [ 1] 2222/tcp                   ALLOW IN    Anywhere
# [ 2] 80/tcp                     ALLOW IN    Anywhere
# [ 3] 443/tcp                    ALLOW IN    Anywhere

# Check current rules without enabling UFW
sudo ufw --dry-run status

# Enable firewall
sudo ufw enable
```

### SSH-Only Configuration (Maximum Security)

**For servers that only need SSH access (no web services):**

```bash
# Reset firewall rules
sudo ufw --force reset

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow only SSH on custom port
sudo ufw allow 2222/tcp   # SSH (secure shell access)

# Enable firewall
sudo ufw enable

# Verify only SSH is allowed
sudo ufw status numbered
# Should show only:
# [ 1] 2222/tcp                   ALLOW IN    Anywhere
```

## Step 6: Additional Security Measures

**Install fail2ban:**

```bash
sudo apt update
sudo apt install fail2ban

# Create custom jail configuration
sudo nano /etc/fail2ban/jail.local
```

**Fail2ban configuration:**

```ini
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = 2222
filter = sshd
logpath = /var/log/auth.log
```

**Start fail2ban:**

```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

**Enable automatic security updates:**

```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

**Create swap file (recommended for small VPS):**

```bash
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## Step 7: Verification and Testing

**Test SSH connection:**

```bash
ssh vps  # Should connect without password using your config
```

**Verify security settings:**

```bash
# Check firewall status and rules
sudo ufw status verbose
sudo ufw status numbered

# Check fail2ban
sudo fail2ban-client status
sudo fail2ban-client status sshd

# Check running services
sudo netstat -tulpn | grep LISTEN

# Check SSH configuration
sudo sshd -T | grep -E "(port|permitrootlogin|passwordauthentication|pubkeyauthentication)"
```

## Important Security Notes

⚠️ **Critical Warnings:**

- Always test SSH connections in a new terminal before closing your current session
- Ensure UFW allows your custom SSH port before enabling the firewall
- Keep your SSH private key secure and use a strong passphrase
- Consider using different SSH keys for different servers

🔒 **Additional Recommendations:**

- Set up monitoring and log analysis
- Configure regular backups
- Use strong, unique passwords for all accounts
- Consider setting up 2FA for additional services
- Regularly update your system: `sudo apt update && sudo apt upgrade`
- Monitor failed login attempts: `sudo grep "Failed password" /var/log/auth.log`

## Troubleshooting

**If locked out of SSH:**

- Use VPS console access from your provider's control panel
- Check SSH configuration: `sudo sshd -t`
- Restart SSH service: `sudo systemctl restart ssh`
- If restart fails: `sudo systemctl daemon-reload` and  `sudo systemctl restart ssh.socket`

**Common issues:**

- Wrong port in firewall rules
- SSH key permissions (should be 600 for private key, 644 for public key)
- SSH config syntax errors
- Using old RSA keys instead of Ed25519

# Packages to Install

- TUI based file explorer - [Yazi](https://github.com/sxyazi/yazi)

```bash
sudo snap install yazi --classic
```

- TUI based docker client [Lazydocker](https://github.com/jesseduffield/lazydocker)

