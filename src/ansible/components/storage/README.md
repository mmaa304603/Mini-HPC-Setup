# Shared data storage

Core runs `preflight`, `head`, `cpu_image` and `verify` entry points for persistent
NFS data at `/shared`. Deployment order is Warewulf preparation → Slurm → storage
→ Spack → Lmod → Warewulf publication. By default it uses existing free space on
the head's root disk. It does not repartition or format block devices, install
Globus, move home directories or copy datasets into OS images.

## Before running initialization

1. Keep the default settings in `config/group_vars/all.yml`:

   ```yaml
   storage_backend: loop
   storage_size_gib: 5
   ```

   The role reserves 5 GiB in `/var/lib/hpc-storage/shared.img`, creates ext4 in
   that **new file only**, and mounts it at `/shared`. No manually supplied UUID
   or extra disk is needed. Filesystem metadata reduces usable capacity slightly.
2. Ensure `/` has at least 11 GiB free before the first deployment: 5 GiB for the
   reservation plus the default 6 GiB `storage_root_reserve_bytes`, inherited
   from core's minimum free-space setting. Capacity is checked before installers
   and again immediately before allocation. This is a minimum, not an estimate
   of all image/software build requirements. The physical VM host also needs
   sufficient backing storage.
3. Declare `storage_users` if more than the setup administrator needs access.
   All accounts and their primary groups must already exist on the head with
   normal UID/GIDs (at least 1000). Workers get matching numeric identities.
   Existing conflicting worker identities stop deployment; they are never
   renumbered. No passwords, sudo rules or additional SSH keys are provisioned.
4. Optional projects use existing head groups and existing memberships:

   ```yaml
   storage_users: [jay]
   storage_projects:
     - name: research
       group: research
       members: [jay]
   ```

   Create the group and assign its head members before deployment. Every declared
   member must also be in `storage_users`. Workers receive these project groups
   and memberships. User/group removal is not automated; review old permissions
   and image memberships explicitly when revoking access.

## Layout and ownership

| Path | Access and purpose |
| --- | --- |
| `/shared/users/<user>` | Private 0700 persistent job inputs and results |
| `/shared/projects/<project>` | 2770 group directories with inherited group-write ACLs |
| `/shared/scratch/<user>` | Private 0700 temporary data; no automatic deletion yet |
| `/opt/spack` | Existing separate read-only software export |

The role persists a file-path mount with `loop,nodiscard,X-fstrim.notrim` in head
fstab, manages only
`/etc/exports.d/hpc-data.exports`, and uses `rw,sync,root_squash,no_subtree_check,mountpoint`
for the private subnet. The mountpoint export option prevents exporting the
underlying directory if the data filesystem is absent. NFS server startup also
requires `/shared`. Unrelated exports are retained.

`storage_mount_options` defaults to `defaults,nofail,x-systemd.device-timeout=30`
so a missing backing file or failed data mount does not prevent head boot. The NFS service still requires
the actual mount. Specify options such as quota mount options explicitly if
needed. Quota limits, backup schedules, monitoring
and scratch retention are not configured by this role. The 1 GiB default
`storage_min_free_bytes` check is an admission threshold, not a capacity plan.

Creation uses real preallocation, not a sparse file. Formatting disables discard
so it does not release that reservation; fstab also excludes the filesystem from
normal fstab-based trim operations. Do not manually trim, truncate, hole-punch,
replace or delete the backing file while using it. Do not copy it into Warewulf
release bundles. The 5 GiB limit bounds shared-data growth, but the data and OS
still share the same physical disk and failure domain. Other head processes can
still fill `/`. Back up data separately; copying a live filesystem image is not
a consistent backup.

Reruns validate the existing file, ext4 UUID, allocation and actual loop-device
backing path. They never resize or reformat it. Changing `storage_size_gib` after
creation fails with a migration message. Ordinary creation failures remove only
their new temporary file. A killed process can leave `.shared-*.building` in the
private backing directory; preflight stops rather than allocating another copy.
After confirming no deployments are active, inspect that unfinished file before
removing it. Never remove `shared.img` to retry a deployment with existing data.

### Optional separate filesystem

To use an already mounted whole XFS/ext4 filesystem on a different device from
`/`, set `storage_backend: existing` and `storage_filesystem_uuid` to the output
of `findmnt -no UUID --mountpoint /shared`. This mode creates no filesystem and
persists the UUID mount. Switching backends does not migrate data; an unexpected
mount or nonempty unmounted `/shared` is refused rather than hidden.

Workers use a native `shared.mount` systemd unit with NFSv4 hard mounts and
`nosuid,nodev`. Slurmd requires and binds to that mount; failed mounting blocks
worker service startup, and unmounting stops it. The underlying image directory
is root-owned 0555, so ordinary jobs cannot silently write into an unmounted
stateless directory. No remote filesystem is mounted during image construction.

A server/network outage can still leave hard-NFS I/O waiting while the mount
remains present. There is no automatic Slurm drain/recovery loop; restore storage
and check worker health before resuming jobs. The head is a storage availability
and throughput dependency. Restrict NFS to trusted cluster clients.

## Deploy and verify

From `src/ansible`, after reviewing configuration and available root space:

```bash
ansible-playbook core/playbooks/site.yml -e core_action=plan
ansible-playbook core/playbooks/site.yml -K -e core_action=preflight
ansible-playbook core/playbooks/site.yml -K -e core_resume=true
# Reboot CPU nodes into the published image during maintenance, then:
ansible-playbook core/playbooks/verify.yml -K
srun -N 3 --ntasks-per-node=1 --chdir=/shared/users/jay hostname
```

Replace `jay` with a configured user. Preflight accepts an absent new loop file
and mount only for planning creation during preflight/deployment; it never creates
them itself. Image preparation and acceptance require the actual mount. Preflight
checks root capacity, existing backing files/mounts and head identities even with
resume enabled. Identity changes affect checkpoint
fingerprints; checkpoints observe the export, mount configuration and image
identity files. Acceptance verifies the NFS source/options and cross-node reads
and writes as every configured user, cleaning only its temporary test directory.
Storage verification runs before Slurm job acceptance.

Selecting core without `storage` does not uninstall an earlier storage setup or
remove its Slurm dependency. A fresh image or explicit migration is needed to
retire storage. CPU publication does not configure the separate Jetson endpoint;
future GPU storage integration must install a client and matching identities too.

## Future Globus integration

A Globus data transfer node can mount this same filesystem and expose selected
user/project paths through a POSIX storage gateway and mapped collections.
It needs the same numeric identities and project memberships. Restrict collection
paths and map authenticated identities to their intended local users. No service
credentials belong in CPU images. Use the current Globus Connect Server workflow;
do not reuse the legacy shell Globus installer unchanged.

Globus networking, endpoint registration and account mapping remain separate
work. Shared storage can be used now without Globus. See the
[POSIX connector](https://docs.globus.org/globus-connect-server/v5/reference/storage-gateway/create/posix/),
[core workflow](../../core/README.md) and [local tests](../tests/README.md).
