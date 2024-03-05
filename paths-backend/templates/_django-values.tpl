{{- define "paths.djangoChartValues" -}}
fullnameOverride: {{ .Release.Name }}
replicaCount: {{ .Values.django.replicaCount }}
image:
  repository: {{ .Values.django.image.repository }}
  tag: {{ .Values.django.image.tag }}
# command: "/bin/bash -c -- while true; do sleep 30; done;"  # useful for debugging the k8s deployment
command: {{ .Values.django.command }}
# imagePullSecrets:
#   - name: {{ include "paths.imagePullSecretName" . }}
imagePullSecrets: []
envConfigs:
  DJANGO_SETTINGS_MODULE: paths.settings
  DEBUG: "{{ if .Values.debug }}1{{ else }}0{{ end }}"
  DEPLOYMENT_TYPE: {{ .Values.deploymentType }}
  ALLOWED_HOSTS: {{ include "paths.backendApiHost" . }},{{ include "paths.backendAdminHost" . }}
  HOSTNAME_INSTANCE_DOMAINS: {{ include "paths.deploymentDomain" . }}
  # TODO
  # MEDIA_FILES_S3_ENDPOINT: TODO
  # MEDIA_FILES_S3_BUCKET: TODO
  # MEDIA_FILES_S3_CUSTOM_DOMAIN: TODO
  REDIS_URL: redis://{{ include "paths.redisName" . }}-master.{{ .Release.Namespace }}.svc.cluster.local
  # PYTHONIOENCODING: utf-8  # Probably it's better to set the locale (line below)
  LC_CTYPE: C.UTF-8
  CONFIGURE_LOGGING: "1"
  {{- if .Values.django.sentry.enabled }}
  SENTRY_DSN: {{ .Values.django.sentry.dsn }}
  {{- end }}
envSecrets:
  # DATABASE_URL: "postgresql://{{ .Values.django.db.user }}:{{ .Values.django.db.password }}@db-cluster-rw/{{ .Values.django.db.database }}"
  SECRET_KEY: {{ include "paths.backendDjangoSecretKey" . }}
  AWS_ACCESS_KEY_ID: {{ .Values.django.awsAccessKeyId }}
  AWS_SECRET_ACCESS_KEY: {{ .Values.django.awsSecretAccessKey }}
ingress:
  enabled: true
  annotations:
    cert-manager.io/cluster-issuer: lets-encrypt
    {{- with .Values.externalDnsTarget }}
    external-dns.alpha.kubernetes.io/target: {{ . }}
    {{- end }}
    traefik.ingress.kubernetes.io/router.middlewares: {{ print .Release.Namespace "-" (include "paths.backendAdminRedirectMiddlewareName" .) "@kubernetescrd" }}
  hosts:
    - host: {{ include "paths.backendAdminHost" . }}
      paths:
        - path: /
          pathType: Prefix
    - host: {{ include "paths.backendApiHost" . }}
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - {{ include "paths.backendAdminHost" . }}
        - {{ include "paths.backendApiHost" . }}
      secretName: {{ include "paths.backendIngressTlsSecretName" . }}
db:
  database: {{ .Values.django.db.database }}
  user: {{ .Values.django.db.user }}
  password: {{ .Values.django.db.password }}
  cluster:
    backup:
      enabled: {{ .Values.django.db.cluster.backup.enabled }}
      s3Secret:
        create: {{ .Values.django.db.cluster.backup.s3Secret.create }}
        awsAccessKeyId: {{ .Values.django.db.cluster.backup.s3Secret.awsAccessKeyId }}
        awsSecretAccessKey: {{ .Values.django.db.cluster.backup.s3Secret.awsSecretAccessKey }}
      endpointUrl: {{ .Values.django.db.cluster.backup.endpointUrl }}
      destinationPath: {{ .Values.django.db.cluster.backup.destinationPath }}
    bootstrapRecovery:
      enabled: {{ .Values.django.db.cluster.bootstrapRecovery.enabled }}
dbMigrations:
  enabled: {{ .Values.django.dbMigrations.enabled }}

redis:
  fullnameOverride: {{ include "paths.redisName" . }}
  architecture: standalone  # default: replication
  auth:
    enabled: false

probes:
  liveness:
    enabled: true
    path: /health
    host: {{ include "paths.backendApiHost" . }}
  readiness:
    enabled: true
    path: /health
    host: {{ include "paths.backendApiHost" . }}

{{- end -}}
