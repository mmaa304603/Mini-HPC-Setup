# HPC telemetry schema v1

All events written by the managed Logstash pipeline receive
`hpc.schema.version: "1.0.0"`. The contract applies at ingestion, so older CPU
images can continue shipping while they await their next maintenance reboot.
The Python helper and Ansible callback also emit the version at the source.
This is an HPC schema version, not a claim of full ECS compliance.

## Identity and correlation

| Field | Meaning |
| --- | --- |
| `@timestamp` | Producer timestamp when supplied and parseable; otherwise the input timestamp. Existing third-party file timestamps are not newly parsed by this stage. |
| `event.ingested` | Logstash processing time, independent of producer time. |
| `event.id` | SHA-256 evidence identity, also used as the Elasticsearch document ID. |
| `hpc.source.event_id` | Original managed producer ID, when present. |
| `hpc.cluster.id` | Operator-configured `elk_cluster_id`; defaults to `mini-hpc`. Set a distinct, stable value per cluster before deployment. |
| `host.name`, `hpc.collector.name` | Shipping host, supplied by Filebeat; embedded JSON cannot replace it. |
| `hpc.source.host` | Producer host when supplied (the controller for Ansible); otherwise shipping host. This is a producer claim, not authenticated identity. |
| `hpc.node.name` | Observed/affected node for health and freshness records; may differ from the shipping head. |
| `hpc.task.target` | Ansible target inventory name. It does not replace the shipping host. |
| `service.name` | Producer service, or an inference from dataset, systemd unit, known file path or syslog app name. Absent when unknown. |
| `hpc.job.id`, `hpc.partition` | Shared Slurm identifiers. Job IDs remain strings to accommodate array/step syntax. |
| `trace.id`, `span.id` | Optional propagated context: non-zero lowercase hex, 32/16 characters respectively. Invalid IDs are removed and tagged. No traces are invented. |
| `hpc.image.version`, `hpc.config.revision` | Reserved, explicitly mapped optional fields. This stage does not discover these values or backfill them. |

Managed Python/callback events receive random source IDs once at emission.
Logstash hashes cluster, shipping host and source ID to obtain `event.id`.
Unstructured/Lmod events instead use Filebeat's `add_id` metadata, which survives
delivery retries. Old images without that processor use a fallback based on input
time, dataset, file path/offset and message.

This is not an exactly-once guarantee: a freshly reharvested unstructured event
can receive a different Filebeat ID, old identical events can share a fallback ID,
and replay across rollover can create the same logical event in multiple indexes.
Keep both logical `event.id` and physical index/document references.

The existing broker preserves `records` and adds an equally sized `evidence`
array in the same order. Each entry contains `event_id`, `index`, `document_id`
and `id: "es:<index>:<document_id>"`. Physical references come from Elasticsearch
hit metadata, not from producer JSON. Legacy hits have physical references even
when they lack `event.id`. References stop resolving after retention deletes data;
retrieval by reference is not added in this stage.

## Normalized fields and source detail

Slurm job-completion records retain `hpc.slurm.*` source fields and also populate
`hpc.job.id`, `name`, `state`, `exit_code`, `nodes`, and `hpc.partition`. Node lists
retain Slurm's compact expression; they are not expanded into individual hosts.
Only `COMPLETED` plus `0:0` establishes success. Known unsuccessful states or
non-zero exit/signal codes establish failure; other records remain unknown.

`event.outcome` remains `success`, `failure`, or `unknown`. Ansible's separate
`hpc.task.status` records `started`, `ok`, `changed`, `failed`, `unreachable`, or
`skipped`; `hpc.changed` remains a boolean. Existing no_log and argument exclusion
still apply, including skipped results.

`event.duration` uses integer nanoseconds for managed operation completion
records. The old `hpc.duration_seconds` remains available. Severity is normalized
when supplied or available as a syslog severity code; unknown severity is omitted.
Collection health is still distinct from service health.

The mapping is in `files/schema-v1.yml`: identifiers are keywords, timestamps
are dates, and existing numeric observations have explicit types. The root uses
`dynamic: false`: unknown fields remain in `_source` but are not automatically
searchable. `hpc.services` and legacy `hpc.slurm` details are flattened fields;
their indexed values are keywords, while JSON values in `_source` are preserved.
CPU ticks/network counters remain source text until the metrics collection stage.

`event.original` is mapped as stored-only and is not automatically populated.
This stage does not introduce an unredacted duplicate of managed diagnostic
messages. Existing journal and service messages may still contain sensitive
content; the schema and evidence IDs do not make logs trustworthy audit records.

## Index rollout and compatibility

New writes use aliases `hpc-logs-v1` and `hpc-logs-build-v1`; initial indexes are
`hpc-logs-v1-000001` and `hpc-logs-build-v1-000001`. Their explicit templates have
priority 300/310, higher than the legacy 200/210 templates. Retention settings are
unchanged: general retention is configurable, verbose builds use two days.

Deployment creates the new templates, policies and aliases before changing
Logstash routing. It never rewrites, reindexes or deletes legacy indexes or
aliases. Existing records retain their original schema and lifecycle policies.
The old `hpc-logs-*` view remains available for history, but mixed text/keyword
mapping generations can cause field-type conflicts in that broad view.

Use the new Kibana **hpc-telemetry-v1** data view (`hpc-logs*-v1-*`) for new data.
Use direct keyword fields such as `event.dataset` and `hpc.job.id`, without
`.keyword`. Broker searches handle both legacy `.keyword` and new direct fields;
new ingestion probes and heartbeat checks use the new schema.

Deploy through the normal core workflow during maintenance, then publish/boot
the updated CPU image and run `core/playbooks/verify.yml`. This applies Logstash
and Filebeat changes; no Elastic package upgrade is part of the schema rollout.
The schema-specific view is not a new agent tool or an access-control boundary.
