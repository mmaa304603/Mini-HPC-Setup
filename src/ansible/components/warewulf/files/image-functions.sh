# Sourced through stdin to wwctl image exec, never run directly on the head.
set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
: "${HPC_HEAD_ROOT:?Missing image execution guard}"
if [[ "$(stat -Lc '%d:%i' /)" == "$HPC_HEAD_ROOT" ]]; then
    echo "Refusing to modify the head root; expected a Warewulf image" >&2
    exit 1
fi
hpc_changed=0
ensure_dir() {
    local path="$1" mode="$2" owner="$3" group="$4"
    local expected
    expected="$(id -u "$owner"):$(getent group "$group" | cut -d: -f3):${mode#0}"
    if [[ ! -d "$path" ]] || [[ "$(stat -Lc '%u:%g:%a' "$path")" != "$expected" ]]; then
        install -d -m "$mode" -o "$owner" -g "$group" "$path"
        hpc_changed=1
    fi
}
put_file() {
    local path="$1" mode="$2" owner="$3" group="$4" tmp expected
    tmp="$(mktemp)"
    cat > "$tmp"
    expected="$(id -u "$owner"):$(getent group "$group" | cut -d: -f3):${mode#0}"
    if [[ ! -f "$path" ]] || ! cmp -s "$tmp" "$path" ||
       [[ "$(stat -Lc '%u:%g:%a' "$path")" != "$expected" ]]; then
        install -D -m "$mode" -o "$owner" -g "$group" "$tmp" "$path"
        hpc_changed=1
    fi
    rm -f "$tmp"
}
install_packages() {
    local before after
    before="$(rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort)"
    dnf -y install "$@"
    after="$(rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort)"
    if [[ "$before" != "$after" ]]; then hpc_changed=1; fi
}
check_identity() {
    local name="$1" uid="$2" group="$3" gid="$4" found
    [[ "$uid" =~ ^[1-9][0-9]*$ && "$gid" =~ ^[1-9][0-9]*$ ]]
    found="$(getent passwd "$uid" || true)"
    [[ -z "$found" || "${found%%:*}" == "$name" ]] || { echo "UID collision for $name" >&2; exit 1; }
    found="$(getent group "$gid" || true)"
    [[ -z "$found" || "${found%%:*}" == "$group" ]] || { echo "GID collision for $group" >&2; exit 1; }
    if getent passwd "$name" >/dev/null; then
        [[ "$(id -u "$name")" == "$uid" && "$(id -g "$name")" == "$gid" ]] ||
            { echo "Existing image account $name has different IDs; refusing renumbering" >&2; exit 1; }
    fi
    if getent group "$group" >/dev/null; then
        [[ "$(getent group "$group" | cut -d: -f3)" == "$gid" ]] ||
            { echo "Existing image group $group has a different GID" >&2; exit 1; }
    fi
}
ensure_identity() {
    local name="$1" uid="$2" group="$3" gid="$4" home="$5" shell="$6"
    check_identity "$name" "$uid" "$group" "$gid"
    if ! getent group "$group" >/dev/null; then
        groupadd --gid "$gid" "$group"; hpc_changed=1
    fi
    if ! getent passwd "$name" >/dev/null; then
        useradd --no-create-home --uid "$uid" --gid "$gid" --home-dir "$home" --shell "$shell" "$name"
        hpc_changed=1
    fi
}
enable_service() {
    if ! systemctl is-enabled "$1" >/dev/null 2>&1; then
        systemctl enable "$1"; hpc_changed=1
    fi
}
