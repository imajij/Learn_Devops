{{/* Full name of every object: <release>-notes */}}
{{- define "notes.fullname" -}}
{{- printf "%s-notes" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Labels shared by all objects */}}
{{- define "notes.labels" -}}
app.kubernetes.io/name: notes
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
environment: {{ .Values.environment }}
{{- end -}}

{{/* Labels used by the Service selector (must never change between upgrades) */}}
{{- define "notes.selectorLabels" -}}
app.kubernetes.io/name: notes
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
