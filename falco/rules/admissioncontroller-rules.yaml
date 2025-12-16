customRules:
  admissioncontroller-rules.yaml: |-
    - rule: Modify Admission Webhook Configuration
      desc: Detect creation or modification of Mutating/ValidatingWebhookConfigurations
      condition: >
        ka.target.resource in (mutatingwebhookconfigurations, validatingwebhookconfigurations) and
        ka.verb in (create, patch, update)
      output: >
        Potential malicious admission controller change |
        user=%ka.user.name verb=%ka.verb resource=%ka.target.resource name=%ka.target.name
      priority: NOTICE
      source: k8s_audit
      tags: [persistence, T1562, T1204, admission, backdoor]
    - rule: Read Admission Webhook Configurations
      desc: Detect attempts to list or get admission controller configurations
      condition: >
        ka.target.resource in (mutatingwebhookconfigurations, validatingwebhookconfigurations)
        and ka.verb in (list, get)
        and not (ka.user.name  in ("system:serviceaccount:kube-system:replicaset-controller", "system:kube-controller-manager", "system:apiserver"))
      output: >
        Enumeration of admission controllers |
        user=%ka.user.name verb=%ka.verb resource=%ka.target.resource
      priority: NOTICE
      source: k8s_audit
      tags: [admission, recon]
    - rule: Delete Admission Webhook Configuration
      desc: Detect deletion of admission controller configurations
      condition: >
        ka.target.resource in (mutatingwebhookconfigurations, validatingwebhookconfigurations) and
        ka.verb=delete
      output: >
        Admission webhook deleted |
        user=%ka.user.name resource=%ka.target.resource name=%ka.target.name
      priority: NOTICE
      source: k8s_audit
      tags: [persistence, admission, T1562]
