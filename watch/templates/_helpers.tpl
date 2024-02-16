{{/*
Expand the name of the chart.
*/}}
{{- define "watch.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "watch.fullname" -}}
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
Encode image pull credentials to be stored in the k8s secret we create.
https://helm.sh/docs/howto/charts_tips_and_tricks/#creating-image-pull-secrets
*/}}
{{- define "watch.imagePullSecretData" -}}
{{- with .Values.imagePullSecret }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" .registry .username .password (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}

{{- define "watch.imagePullSecretName" -}}
{{- default (printf "%s-docker-registry" (include "watch.fullname" .)) .Values.imagePullSecret.name }}
{{- end }}

{{- define "watch.argoCdImagePullSecretName" -}}
{{- default (printf "%s-docker-registry" (include "watch.fullname" .)) .Values.argoCd.imagePullSecret.name }}
{{- end }}

{{- define "watch.backendDjangoArgoCdApplicationName" -}}
{{- default (printf "%s-backend" (include "watch.fullname" .)) .Values.backend.django.argoCdApplication.name }}
{{- end }}

{{- define "watch.backendAdminRedirectMiddlewareName" -}}
{{- default (printf "%s-backend-redirectregex-admin" (include "watch.fullname" .)) .Values.backend.adminRedirectMiddlewareName }}
{{- end }}

{{- define "watch.backendIngressTlsSecretName" -}}
{{- default (printf "%s-backend-tls" (include "watch.fullname" .)) .Values.backend.django.ingress.tlsSecretName }}
{{- end }}

{{- define "watch.uiNextjsArgoCdApplicationName" -}}
{{- default (printf "%s-ui" (include "watch.fullname" .)) .Values.ui.nextjs.argoCdApplication.name }}
{{- end }}

{{- define "watch.uiIngressTlsSecretName" -}}
{{- default (printf "%s-ui-tls" (include "watch.fullname" .)) .Values.ui.nextjs.ingress.tlsSecretName }}
{{- end }}

{{- define "watch.deploymentDomain" -}}
{{- default (printf "watch.%s.%s" .Values.environment .Values.baseDomain) .Values.deploymentDomainOverride }}
{{- end }}

{{- define "watch.backendAdminHost" -}}
{{- default (printf "admin.%s" (include "watch.deploymentDomain" .)) .Values.backendAdminHostOverride }}
{{- end }}

{{- define "watch.backendApiHost" -}}
{{- default (printf "api.%s" (include "watch.deploymentDomain" .)) .Values.backendApiHostOverride }}
{{- end }}

{{- define "watch.uiDeploymentHost" -}}
{{- default (printf "*.%s" (include "watch.deploymentDomain" .)) .Values.uiDeploymentHostOverride }}
{{- end }}

{{- define "watch.backendDjangoSecretKey" -}}
{{- .Values.backend.django.secretKey | default (randAlphaNum 64) }}
{{- end }}
