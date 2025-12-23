{{-/*
Helper templates for whoami chart
*/ -}}
{{- define "whoami.name" -}}
{{- default .Chart.Name .Values.nameOverride -}}
{{- end -}}

{{- define "whoami.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
