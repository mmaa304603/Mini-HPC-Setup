# ELK logging

The core workflow installs Elasticsearch, Logstash, Kibana and Filebeat on the
Rocky 9 head, and Filebeat plus the lightweight observation timer in the CPU image. ELK is included in
`config/group_vars/all.yml` and the core defaults. Setup and the shell installer
are unchanged. The separate Jetson/GPU workflow does not yet install Filebeat.

## Process

1. **Preflight:** validate settings, head memory, disk capacity and installed
   package versions before core takes its lock or runs installers. Existing
   Elasticsearch data/configuration without the core ownership marker is rejected.
   Core will not silently migrate an independently managed deployment.
2. **`head`:** install matching signed Elastic RPMs; configure the three services;
   set up a single-shard index template, rollover alias and retention policy;
   start Filebeat; wait for API readiness; create the `hpc-logs` Kibana data view;
   emit and find a real head journal message in Elasticsearch.
3. **`cpu_image`:** install and enable Filebeat, validate its configuration inside
   the guarded image context, then return to core. No services start in the image.
4. **Warewulf publication:** build the complete image once, with log collection.
5. **`verify`:** after workers boot the new image, check service/API readiness,
   emit a unique journal message on the head and every CPU, and require all of
   those messages to arrive through Filebeat → Logstash → Elasticsearch.

`site.yml` records `elk-head` and `elk-cpu_image` checkpoints after success.
Checkpoint probes check service state, RPMs, configuration and API readiness;
API response counters are not hashed. `verify.yml` performs the live ingestion
check. Selecting ELK changes the deployment fingerprint, so the first deployment
may reconcile earlier phases even with `core_resume=true`.

## Configuration and capacity

Defaults are declared in [defaults/main.yml](defaults/main.yml); override them
in [config/group_vars/all.yml](../../../../config/group_vars/all.yml):

```yaml
core_components: [warewulf, slurm, storage, spack, lmod, elk]
elk_version: '9.5.4'
elk_elasticsearch_heap_mb: 512
elk_logstash_heap_mb: 512
elk_kibana_heap_mb: 2048
elk_pipeline_workers: 1
elk_retention_days: 7
elk_rollover_size: 1gb
```

All four RPMs use the same version. Existing mismatched versions cause a
preflight failure; upgrading an existing Elastic database is an explicit
maintenance operation with backups, not a normal core rerun. The repository is
disabled for ordinary DNF operations and enabled only for these install tasks.
Elasticsearch uses a JVM options fragment; vendor JVM options are preserved.

Default admission requires **7 GiB total head RAM and 10 GiB free under `/var/lib`
for initial package installation**. Reruns with all packages installed require
the core free-space reserve (6 GiB by default). Larger heap settings raise the
memory requirement. These are minimum admission checks, not memory reservations;
the JVMs, Kibana, builds and scheduler still compete for RAM and CPU. For larger
workloads use a separate logging server rather than reducing these checks.
Filebeat also enlarges the CPU image and uses worker RAM. Keep inventory
`slurm_real_memory_mb` below the memory left after the stateless OS and its
services; installing an agent does not automatically reduce Slurm's allocation.

Data stays in `/var/lib/elasticsearch` on the head, outside `/shared` and the CPU
image. Logstash uses a 256 MB persistent queue; Filebeat uses a 128 MB disk queue.
Local structured event streams rotate at about 8 MiB with two retained files.
Normal indexes roll over at one day or the configured shard size, and are eligible for deletion
seven days **after rollover**. Build diagnostics use the separate two-day policy described below. ILM runs
periodically: retention and rollover are **not a hard disk quota**. High log
volume can still fill `/`; monitor it and expand storage or shorten retention.
Warewulf cache/release cleanup does not remove Elasticsearch data.

## Collected logs and observations

The managed head/CPU flow collects journals, Slurm and service files, deployment
results, Spack operation summaries and bounded failed-build diagnostics, Lmod
load/unload events, and Slurm job completion records. A minute timer collects
service/resource observations and checks heartbeat freshness. Verbose Spack build
records use a separate two-day retention policy under `hpc-logs-build-*`.

See [coverage, limits, verification and future agent access](OBSERVABILITY.md).
The `hpc-logs-*` data view includes all these datasets. CPU state is still local
to the stateless OS: reboot or sufficiently long outages can lose unshipped logs.

## Network and trust model

Elasticsearch HTTP/transport, Kibana, and the Logstash management API bind to
**127.0.0.1**. There are no default passwords or unconfigured TLS requirements.
For this trusted lab, Elasticsearch authentication is disabled: **every local
head user, and anyone with a suitable SSH tunnel, can read or modify log data**.
This is unsuitable for a head with untrusted users. Authenticated access and TLS
must be designed before exposing APIs to another host or using this for tenants.

The token-authenticated diagnostic query broker listens on loopback port 9201;
see [agent access boundaries](OBSERVABILITY.md#future-agent-access-and-remaining-scope).

Only the Beats input listens on the head's private IP, TCP 5044. Warewulf opens
it in the private interface zone for the configured cluster CIDR. Traffic there
is unencrypted and unauthenticated, matching the isolated trusted provisioning
network. A compromised cluster node could submit forged logs or excessive data.
No ELK ports are opened in the public zone. Do not expose TCP 5044 externally.

## Run and open Kibana

From `src/ansible`:

```bash
ansible-playbook core/playbooks/site.yml -e core_action=plan
ansible-playbook core/playbooks/site.yml -K -e core_action=preflight
ansible-playbook core/playbooks/site.yml -K -e core_resume=true
# Boot/reboot the CPU nodes into the newly published image during maintenance.
ansible-playbook core/playbooks/verify.yml -K
```

On your workstation, using its reachable SSH address/port for the head:

```bash
ssh -N -L 5601:127.0.0.1:5601 jay@HEAD_SSH_ADDRESS
```

Open `http://localhost:5601` on that workstation. When browsing on the head
itself, use the same URL directly. A VirtualBox NAT SSH forwarding port can be
selected with `ssh -p PORT`; no additional Kibana NAT forwarding is needed.

Diagnostics on the head:

```bash
sudo systemctl status elasticsearch logstash kibana filebeat
sudo journalctl -u elasticsearch -u logstash -u kibana -u filebeat -n 100
sudo tail -n 100 /var/log/elasticsearch/hpc-logs.log
curl --noproxy '*' -fsS http://127.0.0.1:9200/_cat/indices/hpc-logs-*?v
sudo wwctl ssh cpu01 'systemctl status filebeat'
```

If Elasticsearch cannot start, core prints the application log and service
journal, then fails without saving a successful checkpoint. The RPM installer
can create TLS keystore entries before the role replaces its YAML configuration.
The loopback-only configuration explicitly disables HTTP and transport TLS,
as well as authentication, so those retained entries do not implicitly enable
TLS validation. This follows [Elastic's guidance for disabling previously
configured security](https://discuss.elastic.co/t/cannot-disable-security-in-8-1/299857/2).
The keystore, certificates and index data are preserved. Configuration changes
are applied before the start check to avoid starting a fresh JVM twice.

Removing `elk` from the selection does not uninstall packages, stop existing
services, delete data or remove the agent from an already modified image.

## Validation and references

Local tests cover the actual role imports, image rendering/guards, firewall
scope, collector configuration, admission failures, and repeatable API update
conditions. They do not install RPMs or run a live Elastic stack. Deployment and
post-boot ingestion checks are the final integration tests.

The implementation follows Elastic's [RPM installation instructions](https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-with-rpm),
[JVM overrides](https://www.elastic.co/docs/reference/elasticsearch/jvm-settings),
[Filebeat journald input](https://www.elastic.co/docs/reference/beats/filebeat/filebeat-input-journald),
[Logstash output](https://www.elastic.co/docs/reference/beats/filebeat/logstash-output),
and [index lifecycle rollover](https://www.elastic.co/docs/reference/elasticsearch/index-lifecycle-actions/ilm-rollover).
