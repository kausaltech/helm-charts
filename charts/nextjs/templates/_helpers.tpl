{{/*
Expand the name of the chart.
*/}}
{{- define "nextjs-helm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "nextjs-helm.fullname" -}}
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
{{- define "nextjs-helm.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "nextjs-helm.labels" -}}
{{- $appVersion := .Values.appVersion | default .Chart.AppVersion -}}
helm.sh/chart: {{ include "nextjs-helm.chart" . }}
{{ include "nextjs-helm.selectorLabels" . }}
{{- if $appVersion }}
app.kubernetes.io/version: {{ $appVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: server
{{- if .Values.partOf }}
app.kubernetes.io/part-of: {{ .Values.partOf }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nextjs-helm.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nextjs-helm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "nextjs-helm.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "nextjs-helm.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "nextjs-helm.envVariables" -}}
env:
  {{- if .Values.additionalEnv }}
  {{- toYaml .Values.additionalEnv | nindent 2 }}
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

{{-   if or .Values.envSecrets .Values.envConfigs }}
envFrom:
  {{-   if .Values.envSecrets }}
  - secretRef:
      name: {{ .Release.Name }}-env-secrets
  {{-   end }}

  {{-   if .Values.envConfigs }}
  - configMapRef:
      name: {{ .Release.Name }}-env-configmap
  {{-   end }}
  {{-   if .Values.additionalEnvFrom }}
  {{-     toYaml .Values.additionalEnvFrom | nindent 2 }}
  {{-   end }}
{{-   end }}
{{- end }}
