#!/bin/bash

# Source common functions and configuration
source "$(dirname "$0")/../common/functions.sh"
source "$(dirname "$0")/../common/config.sh"

# Install required packages
install_eraider_dependencies() {
    info "Installing eRaider authentication dependencies..."
    
    local packages=(
        "sssd"
        "sssd-ldap"
        "sssd-krb5"
        "sssd-krb5-common"
        "krb5-workstation"
        "openldap-clients"
        "nss-pam-ldapd"
        "authconfig"
    )
    
    for package in "${packages[@]}"; do
        install_package "$package"
    done
}

# Configure SSSD
configure_sssd() {
    info "Configuring SSSD for eRaider authentication..."
    
    # Backup original config
    cp /etc/sssd/sssd.conf /etc/sssd/sssd.conf.bak
    
    # Create new config
    cat > /etc/sssd/sssd.conf << EOF
[sssd]
config_file_version = 2
services = nss, pam
domains = ttu.edu

[domain/ttu.edu]
id_provider = ldap
auth_provider = ldap
chpass_provider = ldap
access_provider = ldap
ldap_uri = ldaps://ldap.ttu.edu
ldap_search_base = dc=ttu,dc=edu
ldap_id_use_start_tls = True
ldap_tls_cacertdir = /etc/openldap/cacerts
ldap_tls_reqcert = demand
ldap_schema = rfc2307bis
ldap_user_object_class = person
ldap_user_name = uid
ldap_user_uid_number = uidNumber
ldap_user_gid_number = gidNumber
ldap_user_home_directory = homeDirectory
ldap_user_shell = loginShell
ldap_group_object_class = posixGroup
ldap_group_name = cn
ldap_group_gid_number = gidNumber
cache_credentials = True
enumerate = True
EOF
    
    # Set correct permissions
    chmod 600 /etc/sssd/sssd.conf
    chown root:root /etc/sssd/sssd.conf
    
    # Enable and start SSSD
    systemctl enable sssd
    systemctl start sssd
}

# Configure PAM
configure_pam() {
    info "Configuring PAM for eRaider authentication..."
    
    # Backup original configs
    cp /etc/pam.d/system-auth /etc/pam.d/system-auth.bak
    cp /etc/pam.d/password-auth /etc/pam.d/password-auth.bak
    
    # Configure system-auth
    cat > /etc/pam.d/system-auth << EOF
#%PAM-1.0
auth        required      pam_env.so
auth        sufficient    pam_unix.so nullok try_first_pass
auth        requisite     pam_succeed_if.so uid >= 1000 quiet_success
auth        sufficient    pam_sss.so use_first_pass
auth        required      pam_deny.so

account     required      pam_unix.so
account     sufficient    pam_localuser.so
account     sufficient    pam_succeed_if.so uid < 1000 quiet
account     [default=bad success=ok user_unknown=ignore] pam_sss.so
account     required      pam_permit.so

password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=
password    sufficient    pam_unix.so sha512 shadow nullok try_first_pass use_authtok
password    sufficient    pam_sss.so use_authtok
password    required      pam_deny.so

session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so
session     optional      pam_sss.so
EOF
    
    # Configure password-auth
    cat > /etc/pam.d/password-auth << EOF
#%PAM-1.0
auth        required      pam_env.so
auth        sufficient    pam_unix.so nullok try_first_pass
auth        requisite     pam_succeed_if.so uid >= 1000 quiet_success
auth        sufficient    pam_sss.so use_first_pass
auth        required      pam_deny.so

account     required      pam_unix.so
account     sufficient    pam_localuser.so
account     sufficient    pam_succeed_if.so uid < 1000 quiet
account     [default=bad success=ok user_unknown=ignore] pam_sss.so
account     required      pam_permit.so

password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=
password    sufficient    pam_unix.so sha512 shadow nullok try_first_pass use_authtok
password    sufficient    pam_sss.so use_authtok
password    required      pam_deny.so

session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so
session     optional      pam_sss.so
EOF
}

# Configure NSS
configure_nss() {
    info "Configuring NSS for eRaider authentication..."
    
    # Backup original config
    cp /etc/nsswitch.conf /etc/nsswitch.conf.bak
    
    # Create new config
    cat > /etc/nsswitch.conf << EOF
passwd:     files sss
shadow:     files sss
group:      files sss
hosts:      files dns myhostname
bootparams: nisplus [NOTFOUND=return] files
ethers:     files
netmasks:   files
networks:   files
protocols:  files
rpc:        files
services:   files sss
netgroup:   files sss
publickey:  nisplus
automount:  files sss
aliases:    files nisplus
EOF
}

# Main execution
main() {
    check_root
    
    install_eraider_dependencies
    configure_sssd
    configure_pam
    configure_nss
    
    info "eRaider authentication setup completed successfully"
}

main "$@" 