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

{{/*
Common labels
*/}}
{{- define "django.labels" -}}
helm.sh/chart: {{ include "django.chart" . }}
{{ include "django.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
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

{{- define "django.envVariables" -}}
{{- if or .Values.envSecrets .Values.envConfigs }} 
envFrom:
{{- if .Values.envSecrets }}
- secretRef:
    name: env-secrets
{{- end }}
{{- if .Values.envConfigs }}
- configMapRef:
    name: env-configmap
{{- end }}
{{- end }}
{{- end }}

{{- define "django.dbBackupS3SecretName" -}}
{{- default (printf "%s-db-backup-s3" (include "django.fullname" .)) .Values.db.cluster.backup.s3Secret.name }}
{{- end }}

{{- define "django.dbClusterName" -}}
{{- default (include "django.fullname" .) .Values.db.cluster.name }}
{{- end }}

{{- define "django.dbSecretName" -}}
{{- default (printf "%s-db-credentials" (include "django.fullname" .)) .Values.db.secret.name }}
{{- end }}

{{- define "django.dbScheduledBackupName" -}}
{{- default (printf "%s-backup" (include "django.fullname" .)) .Values.db.scheduledBackup.name }}
{{- end }}
