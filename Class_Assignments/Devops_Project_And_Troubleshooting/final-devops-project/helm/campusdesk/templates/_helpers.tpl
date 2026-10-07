{{- define "campusdesk.name" -}}{{ .Release.Name }}{{- end }}

{{- define "campusdesk.labels" -}}
app.kubernetes.io/part-of: campusdesk
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{- define "campusdesk.image" -}}
{{ .root.Values.imageRegistry }}/{{ .img.repository }}:{{ .img.tag }}
{{- end }}
