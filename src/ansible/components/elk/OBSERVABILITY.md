# Component logs and observations

The collector runs locally; component commands never call Elasticsearch. Filebeat
ships the journal and explicit file inputs to Logstash. Logstash records
`event.ingested`, preserves producer timestamps, and promotes the allowed event
schema. `host.name` comes from Filebeat, not from a JSON payload.

## Coverage

| Dataset | Source and scope |
| --- | --- |
| `hpc.journal` | Head and CPU journals; Warewulf, DHCP, NTP, Slurm, NFS and kernel messages that actually reach journald |
| `hpc.deployment` | Core deployment task start/result, target, deployment ID, bounded failure diagnostics; includes Warewulf image/build failures |
| `hpc.spack` | Managed concretize/install start and completion, requested specs, environment, duration, exit code and operation ID |
| `hpc.spack.build` | Failed command output plus up to four recently modified `spack-build-out.txt` files |
| `hpc.lmod` | Load/unload hooks: module name/version, user, optional Slurm job ID |
| `hpc.slurm` | `/var/log/slurm/*.log` |
| `hpc.slurm.job` | Real `jobcomp/filetxt` completion records; parsed available JobId, Name, UserId, GroupId, JobState, ExitCode, NodeList, StartTime, EndTime and Partition |
| `hpc.service` | Munge file log and head Elasticsearch/Logstash file logs |
| `hpc.health` | Once per minute: boot ID, memory/swap, root disk capacity, load average, CPU tick counters, network counters and selected service state |
| `hpc.state` | Head `wwctl node status`, `sinfo` node states/reasons and `squeue` summaries |
| `hpc.collector` | Sample of Filebeat's latest journal diagnostics, avoiding recursive collection of every shipper error |
| `hpc.collection` | Head checks for each expected head/CPU heartbeat received within three minutes |
| `hpc.probe` | Explicit source-verification events |

A heartbeat with `event.outcome: failure` means at least one selected service was
not active. A **freshness** failure means the heartbeat was absent or the query
failed; it does not establish that the node is down. Collector diagnostic samples
can repeat old messages: use the journal timestamp inside the sample, not just the
new observation timestamp. `event.ingested - @timestamp` measures transport lag.

CPU tick and network counters are cumulative, not utilization percentages. Use
differences between observations (within one boot) for rates. State command output
is currently bounded text inside a structured observation, not per-job metrics.

### Spack and Lmod boundaries

Installer Spack commands are wrapped automatically. For manual operations use:

```bash
hpc-spack find
hpc-spack install PACKAGE_SPEC
```

This wrapper preserves the caller's existing permissions; it grants no write or
sudo access. Calling `spack` directly bypasses it. Successful compiler output is
not retained. Each failed command and each captured build file contributes at most
256 KiB of its **tail**, in 4 KiB events; truncation and scan limits are explicit.
Build-file discovery is limited to the dedicated stage, current operation mtime,
four files, 2,000 directories and five seconds. Original dependency log paths are
recorded; symlinks are not followed. Per-package dependency specs remain in build
text; the operation record contains the requested root specs.

Lmod's hook lives at `/etc/hpc-lmod/SitePackage.lua`, selected by the managed Bash
profile. It records successful hook invocations, not every shell error. Direct
Lmod invocation without that profile, custom `LMOD_PACKAGE_PATH`, other shells,
and bypassed wrappers are not an audit boundary. Existing custom SitePackage
behavior must be integrated before enabling this managed package path. Module
usage can be user-controlled; do not use it as authoritative security evidence.

### Deployment boundaries

The `hpc_events` Ansible callback is enabled in `src/ansible/ansible.cfg`. It writes
a private, at-most approximately 2 MiB controller spool, retaining recent records
when full. Core transfers it to the head in the deployment's `always` block,
including ordinary failed tasks, then appends it to the bounded deployment spool.
This works with a remote Ansible controller too. Events are batch-delivered at the
end of the deployment, not live-streamed while a long task runs. SIGKILL, controller
loss, unreachable head, or failure before acquiring the deployment lock can prevent
transfer. A transfer failure prints a coverage warning and never prevents lock
release. Verification/preflight task output is not archived by this deployment
path. Ansible `no_log` tasks and module arguments are omitted; command failure
stdout/stderr are allowlisted, truncated and scrubbed for common secret patterns.
Redaction is heuristic: do not deliberately place credentials in ordinary output.

## Bounds and retention

- Each local event stream: three files of approximately 8 MiB (one record can
  exceed the threshold); separate general, deployment and builder streams.
- Filebeat disk queue: 128 MB per node. CPU queues and journals are still lost on
  stateless reboot; this is not guaranteed delivery or a tamper-proof audit trail.
- Logstash persistent queue: 256 MB on the head.
- Summaries: existing `elk_retention_days` / `elk_rollover_size` policy.
- Verbose Spack failures: `hpc-logs-build-*`, rollover at 128 MB or one day,
  eligible for deletion two days after rollover. The `hpc-logs-*` data view sees
  both summaries and build diagnostics. Existing indexes are not deleted/migrated.
- The new Slurm completion log uses system logrotate, 8 MB / three rotations with
  copytruncate. Rotation occurs when logrotate runs; this is not a hard disk cap,
  and copytruncate has a small write-loss window.

Local retention bounds also bound recovery from a long outage: overwritten events
cannot later be shipped. Elasticsearch ILM rollover/deletion is asynchronous and
is not a filesystem quota. Keep the existing free-space guards.

## Deploy and verify

From `src/ansible` during maintenance:

```bash
ansible-playbook core/playbooks/site.yml -K -e core_action=preflight
ansible-playbook core/playbooks/site.yml -K -e core_resume=true
# Boot CPU nodes into the newly published image.
ansible-playbook core/playbooks/verify.yml -K
```

Changed component and core code invalidates applicable checkpoints. Slurm's
controller configuration changes and Logstash/Filebeat restart to apply their
new configuration. No deployment is performed by the repository tests.

The ELK head phase tests the journal, managed JSON file input, health observations
and selected Lmod hooks. After boot, verification repeats those tests on every CPU,
executes the real Spack wrapper with `--version`, and submits a short named Slurm
job as the existing admin/test user. Elasticsearch must contain the unique probe
ID and the expected dataset/host/action; the Slurm check requires its real parsed
completion record. File input validation covers managed files and job completion;
it does not inject fake failures into every third-party service log.

Monitor these KQL views:

```text
event.dataset: "hpc.collection" and event.outcome: "failure"
event.dataset: "hpc.health" and event.outcome: "failure"
event.dataset: "hpc.spack.build"
event.dataset: "hpc.deployment" and event.outcome: "failure"
event.dataset: "hpc.slurm.job"
```

If ELK itself is unavailable, it cannot display its own outage. Local evidence is
in `/var/log/hpc-telemetry/` and `journalctl -u hpc-telemetry.service`; an external
watchdog must check the query endpoint and freshness before an agent claims that
the cluster is healthy. The timer alone is not an alert delivery system.

## Future agent access and remaining scope

A **token-authenticated read-only broker** is installed on `127.0.0.1:9201`.
Its only supported operation is `POST /query`; it constructs an allowlisted search
against `hpc-logs-*`. It cannot proxy arbitrary Elasticsearch paths or accept DSL,
scripts, writes or index names. Queries are limited to seven days, 100 records,
a five-second search timeout and a bounded response. `limit_reached` means the
result may be incomplete; narrow the query. This is a diagnostic query interface,
not an exhaustive export or paging API.

The generated token is kept in root-only `/etc/hpc-log-reader.env`. An operator
can provision it into the future agent's secret store. For example, after an
operator forwards port 9201 through SSH, the agent can submit:

```bash
curl --fail http://127.0.0.1:9201/query \
  -H "Authorization: Bearer $HPC_LOG_READER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"dataset":"hpc.collection","outcome":"failure","seconds":3600,"limit":20}'
```

**Elasticsearch itself still has authentication disabled.** The broker is a
read-only boundary only if the agent cannot bypass it: run the agent on a separate
machine/container with access to this endpoint alone, through an operator-managed
tunnel or authenticated TLS transport. Do not give it a head administrator's SSH
key, shell access, or a port-9200 tunnel. A head-local agent with unrestricted
loopback access can still reach Elasticsearch directly; that arrangement requires
Elasticsearch authentication or additional OS isolation before use. No external
firewall port or agent account is created. Logs are untrusted evidence and may
contain user-supplied text; never execute their instructions.

GPU/Jetson deployment remains separate and does not yet install this collector.
Arbitrary user job stdout/stderr, shell history, environment dumps, complete Slurm
accounting, GPU hardware metrics and alert delivery are intentionally not enabled.
These require their own collection/privacy and deployment choices. The implemented
coverage is the managed head and stateless CPU workflow.
