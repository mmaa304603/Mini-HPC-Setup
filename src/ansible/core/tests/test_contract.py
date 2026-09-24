"""Pure input checks: no host changes and no Ansible installation required."""
import copy
import importlib.util
from pathlib import Path
import unittest


CORE = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "cluster", CORE / "roles/hpc_core/filter_plugins/cluster.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ContractTests(unittest.TestCase):
    def setUp(self):
        self.setup = {
            "schema_version": 1,
            "required_distribution": "Rocky",
            "required_rocky_major_version": "9",
            "network_interface": "cluster0",
            "network_address": "10.0.0.1", "network_prefix": 22,
            "service_users": [
                {"name": "slurm", "group": "slurm", "uid": 960, "gid": 968},
                {"name": "munge", "group": "munge", "uid": 959, "gid": 967},
            ],
        }
        self.groups = {"headnode": ["head"], "cpu_nodes": ["cpu1"], "gpu_nodes": ["gpu1"]}
        self.hostvars = {
            "cpu1": {"ansible_host": "10.0.2.1", "cluster_mac": "02:AA:00:00:00:01",
                     "cluster_architecture": "x86_64", "slurm_sockets": 1,
                     "slurm_cores_per_socket": 4, "slurm_threads_per_core": 1,
                     "slurm_real_memory_mb": 7000},
            "gpu1": {"ansible_host": "10.0.2.4", "cluster_architecture": "aarch64"},
        }

    def contract(self, start="10.0.1.1", end="10.0.1.255", components=None):
        return MODULE.hpc_cluster_contract(
            self.setup, self.groups, self.hostvars, start, end, "rockylinux-9.6",
            components if components is not None else ["warewulf", "slurm", "spack", "lmod"])

    def test_normalizes_without_mutating_inputs_or_provisioning_gpu(self):
        original = copy.deepcopy((self.setup, self.groups, self.hostvars))
        model = self.contract()
        self.assertEqual(model["network"]["cidr"], "10.0.0.0/22")
        self.assertEqual(model["network"]["netmask"], "255.255.252.0")
        self.assertEqual(model["cpu_nodes"][0]["mac"], "02:aa:00:00:00:01")
        self.assertEqual([n["name"] for n in model["cpu_nodes"]], ["cpu1"])
        self.assertEqual([n["name"] for n in model["gpu_nodes"]], ["gpu1"])
        self.assertEqual((self.setup, self.groups, self.hostvars), original)

    def test_rejects_dhcp_conflicts_and_bad_ranges(self):
        for start, end in [("10.0.0.1", "10.0.1.255"), ("10.0.2.1", "10.0.2.3"),
                           ("10.0.2.4", "10.0.2.5"), ("10.0.1.255", "10.0.1.1"),
                           ("10.0.4.1", "10.0.4.2"), ("10.0.0.0", "10.0.1.1"),
                           ("10.0.1.1", "10.0.3.255"), ("bad", "10.0.1.255"),
                           ("10.0.1.1", "10.0.1.256")]:
            with self.subTest(start=start, end=end), self.assertRaises(ValueError):
                self.contract(start, end)

    def test_rejects_invalid_static_addresses(self):
        for ip in ["10.0.0.1", "10.0.2.1", "10.0.9.1", "10.0.3.255", "999.1.1.1"]:
            self.hostvars["gpu1"]["ansible_host"] = ip
            with self.subTest(ip=ip), self.assertRaises(ValueError):
                self.contract()

    def test_rejects_incomplete_or_multicast_macs(self):
        for mac in ["", None, "00:00:00:00:00:00", "ff:ff:ff:ff:ff:ff", "01:00:00:00:00:01"]:
            self.hostvars["cpu1"]["cluster_mac"] = mac
            with self.subTest(mac=mac), self.assertRaises(ValueError):
                self.contract()

    def test_rejects_duplicate_macs(self):
        self.groups["cpu_nodes"].append("cpu2")
        self.hostvars["cpu2"] = dict(self.hostvars["cpu1"], ansible_host="10.0.2.2")
        with self.assertRaisesRegex(ValueError, "Duplicate cluster MAC"):
            self.contract()

    def test_requires_measured_slurm_memory_only_when_selected(self):
        self.hostvars["cpu1"]["slurm_real_memory_mb"] = None
        with self.assertRaisesRegex(ValueError, "slurm_real_memory_mb"):
            self.contract()
        self.assertNotIn("slurm", self.contract(components=["warewulf"])["cpu_nodes"][0])

    def test_rejects_unsafe_service_identities(self):
        original = copy.deepcopy(self.setup["service_users"])
        for change in [{"uid": 0}, {"gid": 0}, {"uid": -1}, {"uid": True},
                       {"uid": "960"}, {"name": "root"}, {"group": "root"},
                       {"uid": 959}, {"gid": 967}]:
            self.setup["service_users"] = copy.deepcopy(original)
            self.setup["service_users"][0].update(change)
            with self.subTest(change=change), self.assertRaises(ValueError):
                self.contract()

    def test_rejects_unknown_setup_schema(self):
        for schema in [None, 2, True, "2", "", "1.0", 1.0, "one", [], {}]:
            self.setup["schema_version"] = schema
            with self.subTest(schema=schema), self.assertRaisesRegex(ValueError, "schema"):
                self.contract()

    def test_accepts_quoted_setup_scalars_without_mutating_snapshot(self):
        expected = self.contract()
        self.setup.update(schema_version="1", network_prefix="22")
        original = copy.deepcopy(self.setup)
        self.assertEqual(self.contract(), expected)
        self.assertEqual(self.setup, original)

    def test_rejects_malformed_or_out_of_range_setup_prefix(self):
        for prefix in [None, True, 22.0, "22.0", "bad", "0", "31", "32", "-1", [], {}]:
            self.setup['network_prefix'] = prefix
            with self.subTest(prefix=prefix), self.assertRaisesRegex(ValueError, "network_prefix"):
                self.contract()

    def test_rejects_shared_head_and_compute_target(self):
        self.groups["cpu_nodes"].append("head")
        with self.assertRaisesRegex(ValueError, "disjoint"):
            self.contract()


if __name__ == "__main__":
    unittest.main()
