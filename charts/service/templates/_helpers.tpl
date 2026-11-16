{{/* Name of the service: the release name unless overridden. */}}
{{- define "service.fullname" -}}
{{- default .Release.Name .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "service.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "service.labels" -}}
{{ include "service.selectorLabels" . }}
app.kubernetes.io/version: {{ include "service.version" . | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
platform.ci/team: {{ required "team is required" .Values.team }}
{{- end -}}

{{- define "service.version" -}}
{{- default .Chart.AppVersion .Values.image.tag | trunc 63 -}}
{{- end -}}

{{/* Digest wins over tag, so a deploy is pinned to exactly what CI built. */}}
{{- define "service.image" -}}
{{- $repo := required "image.repository is required" .Values.image.repository -}}
{{- if .Values.image.digest -}}
{{ $repo }}@{{ .Values.image.digest }}
{{- else -}}
{{ $repo }}:{{ include "service.version" . }}
{{- end -}}
{{- end -}}

{{- define "service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default (include "service.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}
