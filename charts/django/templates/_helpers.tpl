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
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ (default .Chart.AppVersion .Values.appVersion ) | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{ template "common.names.fullname" .Subcharts.redis }}-client: "true"
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
{{- if .Values.db.cluster.create }}
{{- default (printf "%s-db-credentials" (include "django.fullname" .)) .Values.db.secret.name }}
{{- else }}
{{- end }}
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
  {{- if .Values.redis.enabled }}
  - name: REDIS_URL
    value: redis://{{ if .Values.redis.auth.enabled }}:{{ .Values.redis.auth.password }}@{{ end }}{{ template "common.names.fullname" .Subcharts.redis }}-master
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
