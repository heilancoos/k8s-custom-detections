customRules:
  etcd-rules.yaml: |-
    - rule: ETCD Access
      desc: Detect any process accessing etcd client port
      condition: >
        evt.type=connect and
        fd.sport=12379 and 
        not proc.name in (kube-apiserver, kubelite, etcd)
      output: Unexpected etcd connection from %proc.name (%fd.cip:%fd.cport)
      priority: NOTICE
      tags: [etcd, discovery, T1613]
    - rule: ETCD Pod Tampering
      desc: Detects attempts to create, delete, or modify pod objects in etcd using etcdctl
      condition: >
        evt.type=execve and
        proc.name=etcdctl and
        (
          proc.cmdline contains "put" or
          proc.cmdline contains "del"
        ) and
        (
          proc.args contains "/registry/pods" or
          proc.cmdline contains "/registry/pods"
        )
      output: >
        Pod injection attempt via etcdctl detected
        (user=%user.name cmd=%proc.cmdline pid=%proc.pid file=%proc.exe) 
      priority: CRITICAL
      tags: [persistence, etcd, api-bypass, T1525]
    - rule: ETCD read attempt from unusual source detected
      desc: Detects attemtps to read sensitive information from etcd
      condition: >
        evt.type=execve and
        proc.name=etcdctl and 
        (
          proc.args contains "get" or
          proc.cmdline contains "get"
        ) and
        (
          proc.cmdline contains "/registry/pods" or 
          proc.cmdline contains "/registry/secrets" or 
          proc.cmdline contains "/registry/configmaps"
        )
      output: >
        ETCD read attempt detected (user=%user.name cmd=%proc.cmdline pid=%proc.pid file=%proc.exe)
      priority: WARNING
      tags: [etcd, control-plane, T1525]
    - rule: ETCD Snapshot Created
      desc: Detect creation of ETCD snapshots, which may indicate cluster state exfiltration
      condition: >
        evt.type = execve and
        proc.name = "etcdctl" and
        proc.cmdline contains "snapshot" and
        proc.cmdline contains "save"
      output: >
        ETCD snapshot created (proc=%proc.cmdline user=%user.name)
      priority: CRITICAL
      tags: [etcd, exfiltration, discovery, credential-access, T1613]
    - rule: ETCD Registry Deletion
      desc: Detect deletion of Kubernetes objects directly from etcd
      condition: >
        evt.type = execve and
        proc.name = etcdctl and
        proc.cmdline contains "del" and
        proc.cmdline contains "/registry/"
      output: >
        Direct deletion of Kubernetes objects from etcd |
        cmd=%proc.cmdline user=%user.name
      priority: CRITICAL
      tags: [etcd, defense-evasion, T1485]
