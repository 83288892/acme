#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to install acme.sh if not already installed
install_acme_sh() {
  if ! command_exists acme.sh; then
    echo "Installing acme.sh..."
    curl https://get.acme.sh | sh
    if [ "$?" -ne 0 ]; then
      echo -e "${RED}Failed to install acme.sh.${NC}"
      exit 1
    fi
  fi
}

# Function to check if all dependencies are installed
check_dependencies() {
  echo "Checking dependencies..."
  if ! command_exists curl || ! command_exists sudo || ! command_exists socat || ! command_exists acme.sh; then
    echo -e "${RED}Some dependencies are missing. Please install: curl, sudo, socat, acme.sh${NC}"
    read -p "Do you want to install acme.sh now? (y/n): " install_acme_sh_choice
    if [ "$install_acme_sh_choice" = "y" ]; then
      install_acme_sh
    else
      exit 1
    fi
  fi
}

# Function to validate domain name format
validate_domain() {
  # Regex pattern for domain name validation
  domain_pattern="^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
  if [[ ! "$1" =~ $domain_pattern ]]; then
    echo -e "${RED}Invalid domain format. Please enter a valid domain.${NC}"
    return 1
  fi
}

# Function to register a single domain certificate
register_single_domain_cert() {
  read -p "Enter your email address: " email
  read -p "Enter the domain name: " domain
  validate_domain "$domain" || return 1
  
  echo "Registering account..."
  ~/.acme.sh/acme.sh --register-account -m "$email"

  echo "Issuing certificate for $domain..."
  ~/.acme.sh/acme.sh --issue -d "$domain" --standalone
  if [ "$?" -eq 0 ]; then
    echo "Certificate issued successfully."
    create_cert_dir "$domain"
    copy_cert_files "$domain"
  else
    echo -e "${RED}Failed to issue certificate for $domain.${NC}"
  fi
}

# Function to register a multi-domain certificate
register_multi_domain_cert() {
  read -p "Enter your email address: " email
  read -p "Enter the number of domains: " num_domains

  domains=()
  for ((i = 1; i <= num_domains; i++)); do
    read -p "Enter domain $i: " domain
    validate_domain "$domain" || return 1
    domains+=("-d" "$domain")
  done

  echo "Registering account..."
  ~/.acme.sh/acme.sh --register-account -m "$email"

  echo "Issuing multi-domain certificate..."
  ~/.acme.sh/acme.sh --issue "${domains[@]}" --standalone
  if [ "$?" -eq 0 ]; then
    echo "Certificate issued successfully."
    for domain in "${domains[@]:2}"; do
      create_cert_dir "$domain"
      copy_cert_files "$domain"
    done
  else
    echo -e "${RED}Failed to issue multi-domain certificate.${NC}"
  fi
}

# Function to create a directory for the certificate
create_cert_dir() {
  domain="$1"
  cert_dir="/root/cert/$domain"
  mkdir -p "$cert_dir"
  echo "Certificate directory created: $cert_dir"
}

# Function to copy certificate files to the certificate directory
copy_cert_files() {
  domain="$1"
  cert_dir="/root/cert/$domain"
  ~/.acme.sh/acme.sh --install-cert -d "$domain" --cert-file "$cert_dir/cert.pem" \
    --key-file "$cert_dir/key.pem" --fullchain-file "$cert_dir/fullchain.pem" \
    --ca-file "$cert_dir/ca.pem"
  echo "Certificate files copied to $cert_dir"
}

# Function to apply for a certificate using Cloudflare DNS API
apply_with_cf_api() {
  if [ -z "$CF_Key" ] || [ -z "$CF_Email" ]; then
    echo -e "${RED}Cloudflare API key and email not set. Please set them using option [3-1].${NC}"
    return 1
  fi

  read -p "Enter your domain name: " domain
  read -p "Enter your wildcard domain (optional, leave empty if none): " wildcard_domain

  if [ -n "$wildcard_domain" ]; then
    validate_domain "$wildcard_domain" || return 1
  fi
  validate_domain "$domain" || return 1

  domains=("-d" "$domain")
  if [ -n "$wildcard_domain" ]; then
    domains+=("-d" "*.$wildcard_domain")
  fi

  echo "Issuing certificate using Cloudflare DNS API..."
  ~/.acme.sh/acme.sh --issue --dns dns_cf "${domains[@]}"
  if [ "$?" -eq 0 ]; then
    echo "Certificate issued successfully."
    create_cert_dir "$domain"
    copy_cert_files "$domain"
    if [ -n "$wildcard_domain" ]; then
      create_cert_dir "$wildcard_domain"
      copy_cert_files "$wildcard_domain"
    fi
  else
    echo -e "${RED}Failed to issue certificate using Cloudflare DNS API.${NC}"
  fi
}

# Function to uninstall the script and delete certificates
uninstall_script_and_certs() {
  echo "Uninstalling the script and deleting certificates..."
  rm -rf /root/cert
  rm /usr/local/bin/cert.sh
  echo "Script and certificates successfully uninstalled."
}

# Function to display help information
display_help() {
  echo "Usage: cert.sh [option]"
  echo "Options:"
  echo "  [1] Check Dependencies"
  echo "  [2] One-Click Application"
  echo "  [3] CF_API Application"
  echo "  [4] Uninstall Script and Certificates"
  echo "  [5] Help"
  echo "  [6] Exit"
}

# Function to display the main menu
display_main_menu() {
  echo "-------------------------------------"
  echo "Welcome to Cert.sh - One-Click Certificate Application"
  echo "-------------------------------------"
  echo "Main Menu:"
  echo "[1] Check Dependencies"
  echo "[2] One-Click Application"
  echo "    [2-1] Single Domain Certificate"
  echo "    [2-2] Multi-Domain Certificate"
  echo "[3] CF_API Application"
  echo "    [3-1] Set Cloudflare API Key and Email"
  echo "    [3-2] Apply for Certificate with CF_API"
  echo "[4] Uninstall Script and Certificates"
  echo "[5] Help"
  echo "[6] Exit"
  echo "-------------------------------------"
}

# Main script logic
main() {
  check_dependencies

  while true; do
    display_main_menu
    read -p "Enter your choice: " choice

    case "$choice" in
      1)
        echo "Checking dependencies..."
        check_dependencies
        ;;
      2)
        while true; do
          echo "Certificate Application Menu:"
          echo "[2-1] Single Domain Certificate"
          echo "[2-2] Multi-Domain Certificate"
          echo "[9] Back to Main Menu"
          read -p "Enter your choice: " cert_choice

          case "$cert_choice" in
            2-1)
              register_single_domain_cert
              ;;
            2-2)
              register_multi_domain_cert
              ;;
            9)
              break
              ;;
            *)
              echo -e "${RED}Invalid choice. Please try again.${NC}"
              ;;
          esac
        done
        ;;
      3)
        while true; do
          echo "CF_API Application Menu:"
          echo "[3-1] Set Cloudflare API Key and Email"
          echo "[3-2] Apply for Certificate with CF_API"
          echo "[9] Back to Main Menu"
          read -p "Enter your choice: " cf_choice

          case "$cf_choice" in
            3-1)
              read -p "Enter your Cloudflare API Key: " CF_Key
              read -p "Enter your Cloudflare email: " CF_Email
              export CF_Key CF_Email
              echo "Cloudflare API Key and Email set successfully."
              ;;
            3-2)
              apply_with_cf_api
              ;;
            9)
              break
              ;;
            *)
              echo -e "${RED}Invalid choice. Please try again.${NC}"
              ;;
          esac
        done
        ;;
      4)
        uninstall_script_and_certs
        exit 0
        ;;
      5)
        display_help
        ;;
      6)
        echo "Exiting Cert.sh..."
        exit 0
        ;;
      *)
        echo -e "${RED}Invalid choice. Please try again.${NC}"
        ;;
    esac
  done
}

main
