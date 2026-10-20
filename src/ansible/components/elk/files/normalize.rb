# HPC event schema v1. Only local variables are mutated while processing events.
require "digest"
require "json"

def register(params)
  @cluster_id = params.fetch("cluster_id")
end

def scalar(value)
  return nil unless value.is_a?(String) || value.is_a?(Numeric)
  text = value.to_s
  text.empty? ? nil : text
end

def filter(event)
  # Producer IDs survive reharvesting. Filebeat IDs survive queue retries, but
  # are regenerated if an unstructured source is harvested again from scratch.
  source_id = scalar(event.get("[event][id]"))
  shipper_id = scalar(event.get("[@metadata][_id]"))
  host = scalar(event.get("[host][name]"))
  identity = if source_id
    ["producer", source_id]
  elsif shipper_id
    ["filebeat", shipper_id]
  else
    # Compatibility for old CPU images without add_id. Not a universal deduper.
    ["legacy", event.get("@timestamp").to_s, event.get("[event][dataset]"),
     event.get("[log][file][path]"), event.get("[log][offset]"), event.get("message")]
  end
  event.set("[event][id]", Digest::SHA256.hexdigest(JSON.generate([@cluster_id, host, identity])))
  event.set("[hpc][source][event_id]", source_id) if source_id
  event.set("[hpc][schema][version]", "1.0.0")
  event.set("[hpc][cluster][id]", @cluster_id)
  event.set("[hpc][collector][name]", host) if host
  event.set("[hpc][source][host]", host) if host && !scalar(event.get("[hpc][source][host]"))
  event.set("[event][kind]", "event") unless scalar(event.get("[event][kind]"))
  event.set("[event][outcome]", "unknown") unless %w[success failure unknown].include?(event.get("[event][outcome]"))

  dataset = event.get("[event][dataset]")
  if dataset == "hpc.slurm.job"
    {"JobId" => "id", "Name" => "name", "JobState" => "state",
     "ExitCode" => "exit_code", "NodeList" => "nodes"}.each do |source, target|
      value = scalar(event.get("[hpc][slurm][#{source}]"))
      event.set("[hpc][job][#{target}]", value) if value
    end
    partition = scalar(event.get("[hpc][slurm][Partition]"))
    event.set("[hpc][partition]", partition) if partition
    event.set("[event][action]", "job-completed")
    state = event.get("[hpc][job][state]")
    exit_code = event.get("[hpc][job][exit_code]")
    outcome = if state == "COMPLETED" && exit_code == "0:0"
      "success"
    elsif %w[FAILED CANCELLED TIMEOUT NODE_FAIL OUT_OF_MEMORY PREEMPTED BOOT_FAIL DEADLINE].include?(state) ||
          (exit_code && exit_code.match?(/\A\d+:\d+\z/) && exit_code != "0:0")
      "failure"
    else
      "unknown"
    end
    event.set("[event][outcome]", outcome)
  end
  job_id = scalar(event.get("[hpc][job][id]"))
  job_id ? event.set("[hpc][job][id]", job_id) : event.remove("[hpc][job][id]")

  service = scalar(event.get("[service][name]"))
  unless service
    service = {"hpc.spack" => "spack", "hpc.spack.build" => "spack",
               "hpc.lmod" => "lmod", "hpc.deployment" => "ansible",
               "hpc.slurm.job" => "slurmctld"}[dataset]
    service ||= "hpc-telemetry" if %w[hpc.health hpc.state hpc.collector hpc.collection hpc.probe].include?(dataset)
    unit = scalar(event.get("[systemd][unit]"))
    service ||= unit.sub(/\.service\z/, "") if unit
    path = scalar(event.get("[log][file][path]"))
    if !service && path
      service = if path.include?("/elasticsearch/")
        "elasticsearch"
      elsif path.include?("/logstash/")
        "logstash"
      elsif path.include?("/munge/")
        "munged"
      elsif path.match?(%r{/slurm/(slurmctld|slurmd|slurmdbd)\.log\z})
        File.basename(path, ".log")
      end
    end
    service ||= scalar(event.get("[log][syslog][appname]"))
  end
  event.set("[service][name]", service) if service

  level = scalar(event.get("[log][level]"))
  severity = event.get("[log][syslog][severity][code]")
  level ||= %w[emergency alert critical error warning notice informational debug][severity] if severity.is_a?(Integer) && severity.between?(0, 7)
  event.set("[log][level]", level.downcase) if level
  # Context is accepted only when it has the standard non-zero hexadecimal form.
  {"trace" => 32, "span" => 16}.each do |field, length|
    value = event.get("[#{field}][id]")
    next unless value
    if value.is_a?(String) && value.match?(/\A[0-9a-f]{#{length}}\z/) && value != "0" * length
      next
    end
    event.remove("[#{field}][id]")
    event.tag("_hpc_invalid_#{field}_id")
  end
  [event]
end
