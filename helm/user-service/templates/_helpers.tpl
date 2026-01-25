{{/*
=============================================================================
Helm Template Helpers for User Service
=============================================================================

Key Concept: Helm Template Helpers
-----------------------------------
Helper templates are reusable template snippets that can be called from
other templates. They help reduce duplication and maintain consistency.

Convention:
- Names starting with _ are private (not rendered as files)
- Use 'define' to create named templates
- Use 'include' or 'template' to call them
*/}}

{{/*
Expand the name of the chart.
Used as a base for resource naming.
*/}}
{{- define "user-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited.
If release name contains chart name it will be used as a full name.
*/}}
{{- define "user-service.fullname" -}}
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
{{- define "user-service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to all resources.
Follows Kubernetes recommended labels:
https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/
*/}}
{{- define "user-service.labels" -}}
helm.sh/chart: {{ include "user-service.chart" . }}
{{ include "user-service.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: backend
app.kubernetes.io/part-of: api-platform
{{- end }}

{{/*
Selector labels used in pod selectors and service selectors.
Must match between Deployment.spec.selector and Deployment.spec.template.metadata.labels
*/}}
{{- define "user-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "user-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "user-service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "user-service.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the image name with registry and tag.
*/}}
{{- define "user-service.image" -}}
{{- $registry := .Values.global.imageRegistry | default "" }}
{{- $repository := .Values.image.repository }}
{{- $tag := .Values.image.tag | default .Chart.AppVersion }}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- else }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
{{- end }}

{{/*
Create the name for the secrets.
*/}}
{{- define "user-service.secretName" -}}
{{- printf "%s-secrets" (include "user-service.fullname" .) }}
{{- end }}

{{/*
Create the name for the ConfigMap.
*/}}
{{- define "user-service.configMapName" -}}
{{- printf "%s-config" (include "user-service.fullname" .) }}
{{- end }}

{{/*
Create the name for the PVC.
*/}}
{{- define "user-service.pvcName" -}}
{{- printf "%s-data" (include "user-service.fullname" .) }}
{{- end }}

