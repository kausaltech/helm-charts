{{/*
Expand the name of the chart.
*/}}
{{- define "django.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "django.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "django.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "django.appImage" -}}
{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}
{{- end }}

{{- define "django.appImageConfig" -}}
image: {{ include "django.appImage" . }}
imagePullPolicy: {{ .Values.image.pullPolicy | default "IfNotPresent" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "django.labels" -}}
{{ include "django.selectorLabels" . }}
{{- with (default .Chart.AppVersion .Values.appVersion) }}
app.kubernetes.io/version: {{ . | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{ template "valkey.fullname" .Subcharts.valkey }}-client: "true"
{{- end }}

{{/*
Labels used in spec.selector of the web Deployment and the Service.

This deliberately renders exactly what django.labels rendered before the
app.kubernetes.io/version guard was fixed: name, instance, managed-by and the
valkey client label, but never version. Two reasons it cannot just be
django.selectorLabels:

  - Deployment.spec.selector is immutable. Existing releases already have
    managed-by and the valkey client label in their selector, so dropping them
    fails the upgrade with "field is immutable".
  - Service.spec.selector is mutable, but adding version would make it change on
    every build, briefly selecting no ready pods and blanking the endpoints.

The cleaner shape (selectorLabels + component) needs the Deployment recreated, so
it is left for a release that can afford that.
*/}}
{{- define "django.stableSelectorLabels" -}}
{{ include "django.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{ template "valkey.fullname" .Subcharts.valkey }}-client: "true"
{{- end }}

{{/*
Selector labels
*/}}
{{- define "django.selectorLabels" -}}
app.kubernetes.io/name: {{ include "django.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "django.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "django.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "django.dbBackupS3SecretName" -}}
{{- default (printf "%s-db-backup-s3" (include "django.fullname" .)) .Values.db.cluster.backup.s3Secret.name }}
{{- end }}

{{- define "django.dbClusterName" -}}
{{- default (printf "%s-db" (include "django.fullname" .)) .Values.db.cluster.name }}
{{- end }}

{{- define "django.dbSecretName" -}}
{{- default (printf "%s-db-credentials" (include "django.fullname" .)) .Values.db.secret.name }}
{{- end }}

{{- define "django.dbScheduledBackupName" -}}
{{- default (printf "%s-backup" (include "django.fullname" .)) .Values.db.cluster.scheduledBackup.name }}
{{- end }}

{{- define "django.envVariables" -}}
env:
  {{- if .Values.db.cluster.create }}
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: {{ include "django.dbClusterName" . }}-app
        key: uri
  - name: PGPASSFILE
    value: /run/secrets/db-credentials/pgpass
  {{- end }}
  {{- if .Values.proxy.enabled }}
  - name: CADDY_PORT
    value: "{{ .Values.proxy.containerPort }}"
  {{- end }}
  {{- if .Values.elasticsearch.enabled }}
  - name: ELASTICSEARCH_URL
    value: http://{{ template "elasticsearch.service.name" .Subcharts.elasticsearch }}:9200
  {{- end }}
  {{- if .Values.valkey.enabled }}
  - name: REDIS_URL
    value: redis://{{ if .Values.valkey.auth.enabled }}:{{ .Values.valkey.auth.aclUsers.default.password }}@{{ end }}{{ template "valkey.fullname" .Subcharts.valkey }}
  {{- end }}
  - name: NODE_NAME
    valueFrom:
      fieldRef:
        fieldPath: spec.nodeName
  - name: POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: POD_NAMESPACE
    valueFrom:
      fieldRef:
        fieldPath: metadata.namespace
  {{- if .Values.additionalEnv }}
  {{- toYaml .Values.additionalEnv | nindent 2 }}
  {{- end }}

  {{- if or .Values.envSecrets .Values.envConfigs }}
envFrom:
  {{- if .Values.envSecrets }}
  - secretRef:
      name: {{ .Release.Name }}-env-secrets
  {{- end }}

  {{- if .Values.envConfigs }}
  - configMapRef:
      name: {{ .Release.Name }}-env-configmap
  {{- end }}

  {{- if .Values.additionalEnvFrom }}
    {{- toYaml .Values.additionalEnvFrom | nindent 2 }}
  {{- end }}
  {{- end }}

{{- end }}

{{- define "django.secretVolumes" -}}
{{- if and .Values.externalSecrets.enabled .Values.externalSecrets.targets }}
{{- range .Values.externalSecrets.targets }}
{{- if .mountPath }}
- name: secret-{{ .name }}
  secret:
    secretName: {{ .name }}
{{- end }}{{- end }}{{- end }}
{{- if $.Values.db.cluster.create }}
- name: db-credentials
  secret:
    secretName: {{ include "django.dbClusterName" . }}-app
{{- end }}
{{- end }}

{{/*
django-prometheus multiprocess directory.

These three helpers MUST be used together and only on pods that run the metrics
exporter sidecar -- i.e. the web Deployment. prometheus_client selects multiprocess
mode on the mere presence of PROMETHEUS_MULTIPROC_DIR and then opens files under it
without creating the directory, so setting the env var without mounting the volume
crashes the pod at the first metric construction. Setting neither is safe: the client
falls back to single-process MutexValue.

Non-web pods (celery, cronjobs, migrations) deliberately get none of this. They never
build the Django middleware stack, so they never construct django-prometheus metrics
and never wrote to the directory in the first place.

The volume is a tmpfs, so its contents count against the pod's memory limit; sizeLimit
bounds that. Alert on django_prometheus_multiproc_dir_files well before the limit --
a full volume surfaces as ENOSPC inside the request path.
*/}}
{{- define "django.metricsMultiprocEnv" -}}
{{- if .Values.metrics.enabled }}
- name: PROMETHEUS_MULTIPROC_DIR
  value: {{ .Values.metrics.multiprocDir | quote }}
{{- end }}
{{- end }}

{{- define "django.metricsMultiprocVolume" -}}
{{- if .Values.metrics.enabled }}
- name: prometheus-multiproc
  emptyDir:
    medium: Memory
    sizeLimit: {{ .Values.metrics.multiprocSizeLimit }}
{{- end }}
{{- end }}

{{- define "django.metricsMultiprocVolumeMount" -}}
{{- if .Values.metrics.enabled }}
- name: prometheus-multiproc
  mountPath: {{ .Values.metrics.multiprocDir }}
{{- end }}
{{- end }}

{{- define "django.secretVolumeMounts" -}}
{{- if and .Values.externalSecrets.enabled .Values.externalSecrets.targets }}
{{- range .Values.externalSecrets.targets }}
{{- if .mountPath }}
- name: secret-{{ .name }}
  mountPath: {{ .mountPath }}
  readOnly: true
{{- if .subPath }}
  subPath: {{ .subPath }}
{{- end }}
{{- end }}{{- end }}{{- end }}
{{- if $.Values.db.cluster.create }}
- name: db-credentials
  mountPath: /run/secrets/db-credentials
  readOnly: true
{{- end }}
{{- end }}

{{- define "django.proxyImageConfig "}}
{{- if .Values.proxy.useAppImage }}
{{- include "django.appImageConfig" . }}
{{- else -}}
image: {{ .Values.proxy.repository }}:{{ .Values.proxy.tag }}
{{- end }}
{{- end }}
