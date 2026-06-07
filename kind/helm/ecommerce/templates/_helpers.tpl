{{/*
_helpers.tpl — Reusable template snippets.
These are named templates called with {{ include "ecommerce.<name>" . }}
throughout the other template files.
*/}}

{{/*
Full image path: registry/image:tag
e.g. us-central1-docker.pkg.dev/google-samples/microservices-demo/frontend:v0.10.5
*/}}
{{- define "ecommerce.image" -}}
{{- printf "%s/%s:%s" .Values.global.imageRegistry .image .Values.global.imageTag -}}
{{- end }}

{{/*
Common labels applied to every resource — used by kubectl selectors and Helm tracking
*/}}
{{- define "ecommerce.labels" -}}
app.kubernetes.io/part-of: ecommerce
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{/*
Selector labels — used by Service selectors and Deployment matchLabels
*/}}
{{- define "ecommerce.selectorLabels" -}}
app: {{ .app }}
{{- end }}

{{/*
Namespace — pulled from global values
*/}}
{{- define "ecommerce.namespace" -}}
{{ .Values.global.namespace }}
{{- end }}
