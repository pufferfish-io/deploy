{{- define "telegram-forwarder.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "telegram-forwarder.fullname" -}}
{{- printf "%s" (include "telegram-forwarder.name" .) -}}
{{- end }}
