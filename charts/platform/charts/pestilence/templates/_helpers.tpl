{{- define "pestilence.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "pestilence.namespace" -}}
{{- default "pestilence" .Values.namespace.name -}}
{{- end -}}

{{- define "pestilence.scarabNamespace" -}}
{{- default "scarab" .Values.scarabNamespace.name -}}
{{- end -}}

{{- define "pestilence.townNamespace" -}}
{{- default "town" .Values.townNamespace.name -}}
{{- end -}}

{{- define "pestilence.traefikNamespace" -}}
{{- default "traefik" .Values.edge.traefikNamespace -}}
{{- end -}}

{{- define "pestilence.serviceAccountName" -}}
{{- default "pestilence" .Values.serviceAccount.name -}}
{{- end -}}

{{- define "pestilence.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}

{{- define "pestilence.assertionConfigMapName" -}}
{{- default "town-assertion-pubkey" .Values.assertion.existingConfigMap -}}
{{- end -}}

{{/* The scarab images pestilence stamps into each workspace it creates. Empty means
     the chart's appVersion, so a release never stamps a stale image tag. */}}
{{- define "pestilence.agentImage" -}}
{{- .Values.workspaceImages.agent | default (printf "ghcr.io/gobackto-work/scarab-agent:%s" .Chart.AppVersion) -}}
{{- end -}}

{{- define "pestilence.brokerImage" -}}
{{- .Values.workspaceImages.broker | default (printf "ghcr.io/gobackto-work/scarab-broker:%s" .Chart.AppVersion) -}}
{{- end -}}

{{- define "pestilence.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "pestilence.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
agents.gobackto.work/component: control-plane
{{- end -}}

{{- define "pestilence.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pestilence.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
agents.gobackto.work/component: control-plane
{{- end -}}
