"""Validate the setup handoff and build one model for all component phases.

Only standard-library code: address validation does not require ansible.utils
or netaddr. This filter never reads or changes the host operating system.
"""

from collections.abc import Mapping
from ipaddress import IPv4Address, IPv4Interface
import re


def _require(condition, message):
    if not condition:
        raise ValueError(message)


def _positive_integer(value, label):
    _require(isinstance(value, int) and not isinstance(value, bool)
             and 0 < value < 2**31, f"{label} must be a positive integer")
    return value


def _handoff_integer(value, label):
    """Setup's templated scalar defaults can serialize as quoted decimals."""
    if isinstance(value, str) and re.fullmatch(r"[0-9]{1,10}", value):
        return int(value)
    _require(isinstance(value, int) and not isinstance(value, bool),
             f"{label} must be an integer or decimal integer string; got {value!r}")
    return value


def _address(value, label):
    _require(isinstance(value, str), f"{label} must be an IPv4 address string")
    try:
        return IPv4Address(value)
    except ValueError as error:
        raise ValueError(f"{label}: invalid IPv4 address {value!r}") from error


def hpc_cluster_contract(setup, groups, hostvars, dhcp_start, dhcp_end,
                         image, components):
    """Return normalized topology; reject incomplete or conflicting inputs."""
    _require(isinstance(setup, Mapping), "setup.yml must contain a mapping")
    schema = _handoff_integer(setup.get("schema_version"), "setup schema_version")
    _require(schema == 1,
             f"Unsupported setup schema_version {schema!r}; expected 1")
    _require(setup.get("required_distribution") == "Rocky"
             and str(setup.get("required_rocky_major_version")) == "9",
             "Completed setup must target Rocky Linux 9")
    interface = setup.get("network_interface")
    _require(isinstance(interface, str) and bool(interface.strip()),
             "setup network_interface is required")
    prefix = _handoff_integer(setup.get("network_prefix"), "setup network_prefix")
    _require(1 <= prefix <= 30,
             "setup network_prefix must support a multi-node IPv4 subnet (1..30)")
    head_ip = _address(setup.get("network_address"), "Head address")
    network = IPv4Interface(f"{head_ip}/{prefix}").network

    def usable(address, label):
        _require(address in network
                 and address not in (network.network_address, network.broadcast_address),
                 f"{label} must be a usable address in {network}")

    usable(head_ip, "Head address")
    start, end = _address(dhcp_start, "DHCP start"), _address(dhcp_end, "DHCP end")
    usable(start, "DHCP start")
    usable(end, "DHCP end")
    _require(start <= end, "DHCP start must not exceed DHCP end")
    _require(not start <= head_ip <= end, "DHCP range overlaps the head address")
    _require(isinstance(image, str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", image),
             "core_cpu_image must be a simple Warewulf image name")

    identities = setup.get("service_users")
    _require(isinstance(identities, list) and len(identities) == 2
             and all(isinstance(item, Mapping) for item in identities),
             "setup service_users must contain exactly slurm and munge")
    _require({item.get("name") for item in identities} == {"slurm", "munge"},
             "Only slurm and munge service identities are supported")
    service_users = []
    for item in identities:
        name = item["name"]
        _require(item.get("group") == name, f"{name} must use its own service group")
        service_users.append({
            "name": name, "group": name,
            "uid": _positive_integer(item.get("uid"), f"{name} UID"),
            "gid": _positive_integer(item.get("gid"), f"{name} GID"),
        })
    _require(len({item["uid"] for item in service_users}) == 2
             and len({item["gid"] for item in service_users}) == 2,
             "Slurm and Munge must have distinct UIDs and distinct GIDs")

    heads, cpus, gpus = (list(groups.get(key, []))
                         for key in ("headnode", "cpu_nodes", "gpu_nodes"))
    _require(len(heads) == 1 and cpus, "One head and at least one CPU node are required")
    _require(len(set(heads + cpus + gpus)) == len(heads + cpus + gpus),
             "Head, CPU, and GPU groups must be disjoint")
    addresses, macs = {head_ip}, set()
    cpu_nodes, gpu_nodes = [], []
    for names, target in ((cpus, cpu_nodes), (gpus, gpu_nodes)):
        for name in names:
            _require(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", name),
                     f"Invalid node name: {name!r}")
            values = hostvars[name]
            ip = _address(values.get("ansible_host"), f"{name} ansible_host")
            usable(ip, name)
            _require(ip not in addresses, f"Duplicate cluster address: {ip}")
            _require(not start <= ip <= end, f"DHCP range overlaps static node {name}")
            addresses.add(ip)
            node = {"name": name, "address": str(ip),
                    "architecture": values.get("cluster_architecture")}
            if target is cpu_nodes:
                _require(node["architecture"] == "x86_64", f"{name} must use x86_64")
                mac = values.get("cluster_mac", "")
                _require(isinstance(mac, str)
                         and re.fullmatch(r"(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}", mac),
                         f"{name} requires its actual PXE NIC cluster_mac")
                mac = mac.lower()
                _require(mac != "00:00:00:00:00:00" and not int(mac[:2], 16) & 1,
                         f"{name} requires a nonzero unicast MAC address")
                _require(mac not in macs, f"Duplicate cluster MAC: {mac}")
                macs.add(mac)
                node["mac"] = mac
                if "slurm" in components:
                    node["slurm"] = {
                        field: _positive_integer(values.get("slurm_" + field), f"{name} slurm_{field}")
                        for field in ("sockets", "cores_per_socket", "threads_per_core", "real_memory_mb")
                    }
            target.append(node)

    return {
        "schema_version": 1,
        "head": {"name": heads[0], "address": str(head_ip)},
        "network": {"interface": interface, "address": str(head_ip),
                    "prefix": prefix, "network": str(network.network_address),
                    "cidr": str(network), "netmask": str(network.netmask),
                    "dhcp_start": str(start), "dhcp_end": str(end)},
        "service_users": service_users,
        "cpu_image": image, "cpu_nodes": cpu_nodes, "gpu_nodes": gpu_nodes,
    }


class FilterModule:
    def filters(self):
        return {"hpc_cluster_contract": hpc_cluster_contract}
