orgAllowlist: ${github_repo_allowlist}

github:
  user: ${github_username}
  token: ${github_token}
  secret: "${webhook_secret}"  # ✅ Added quotes to handle special characters

service:
  type: LoadBalancer
  port: 80
  targetPort: 4141

image:
  repository: ghcr.io/runatlantis/atlantis
  tag: ${atlantis_image_tag}
  pullPolicy: IfNotPresent

resources:
  requests:
    memory: ${requests_memory}
    cpu: ${requests_cpu}
  limits:
    memory: ${limits_memory}
    cpu: ${limits_cpu}

serviceAccount:
  create: true
  name: atlantis
  annotations:
    eks.amazonaws.com/role-arn: ${atlantis_role_arn}

environment:
  AWS_REGION: ${region}
  AWS_STS_REGIONAL_ENDPOINTS: "regional"
  ATLANTIS_LOG_LEVEL: "info"
  ATLANTIS_WRITE_GIT_CREDS: "true"
  ATLANTIS_DATA_DIR: "/atlantis-data"

dataStorage: ${storage_size}
storageClassName: atlantis-production

livenessProbe:
  enabled: true
  initialDelaySeconds: 120
  periodSeconds: 60
  timeoutSeconds: 15
  failureThreshold: 5
  successThreshold: 1

readinessProbe:
  enabled: true
  initialDelaySeconds: 90
  periodSeconds: 30
  timeoutSeconds: 15
  failureThreshold: 5
  successThreshold: 1

statefulSet:
  securityContext:
    runAsUser: 100
    runAsGroup: 1000
    fsGroup: 1000

replicaCount: 1
logLevel: info

ingress:
  enabled: false
