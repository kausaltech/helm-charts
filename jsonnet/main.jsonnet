local addMixin = (import 'kube-prometheus/lib/mixin.libsonnet');

local kubernetesMixin = addMixin({
  name: 'kubernetes',
  dashboardFolder: 'Kubernetes',
  mixin: (import 'kubernetes-mixin/mixin.libsonnet') + {
    _config+:: {
      cadvisorSelector: 'job="kubelet"',
      kubeletSelector: 'job="kubelet"',
      kubeSchedulerSelector: 'job="kubelet"',
      kubeControllerManagerSelector: 'job="kubelet"',
      kubeApiserverSelector: 'job="kubelet"',
      kubeProxySelector: 'job="kubelet"',
    },
  },
});

local nodeExporterMixin = addMixin({
  name: 'node-exporter',
  dashboardFolder: 'General',
  mixin: (import 'node-mixin/mixin.libsonnet') + {
    _config+:: {
      nodeExporterSelector: 'job="node-exporter"'
    },
    grafanaDashboards:: std.mergePatch(super.grafanaDashboards, {
      'nodes-darwin.json': null,
    }),
  },
});

local corednsMixin = addMixin({
  name: 'coredns',
  dashboardFolder: 'DNS',
  mixin: (import 'coredns-mixin/mixin.libsonnet') + {
    _config+:: {
      corednsSelector: 'job="coredns"',
    },
  },
});

local grafanaMixin = addMixin({
  name: 'grafana',
  dashboardFolder: 'Grafana',
  mixin: (import 'grafana-mixin/mixin.libsonnet') + {
    _config+:: {},
  },
});

local prometheusMixin = addMixin({
  name: 'prometheus',
  dashboardFolder: 'Prometheus',
  mixin: (import 'prometheus/mixin.libsonnet') + {
    _config+:: {},
  },
});

local prometheusOperatorMixin = addMixin({
  name: 'prometheus-operator',
  dashboardFolder: 'Prometheus Operator',
  mixin: (import 'prometheus-operator-mixin/mixin.libsonnet') + {
    _config+:: {},
  },
});

local removeJsonExtension(name) =
  local extensionIndex = std.findSubstr('.json', name);
  local n = if std.length(extensionIndex) < 1 then name else std.substr(name, 0, extensionIndex[0]);
  n;

local grafanaDashboardConfigMap(folder, name, json) = {
  apiVersion: 'v1',
  kind: 'ConfigMap',
  metadata: {
    name: 'grafana-dashboard-%s' % removeJsonExtension(name),
    namespace: 'monitoring',
    labels: {
      grafana_dashboard: '1',
    },
  },
  data: {
    [name]: std.manifestJsonEx(json, '    '),
  },
};

local generateGrafanaDashboardConfigMaps(mixin) = if std.objectHas(mixin, 'grafanaDashboards') && mixin.grafanaDashboards != null then {
  ['grafana-dashboard-' + removeJsonExtension(name)]: grafanaDashboardConfigMap(folder, name, mixin.grafanaDashboards[folder][name])
  for folder in std.objectFields(mixin.grafanaDashboards)
  for name in std.objectFields(mixin.grafanaDashboards[folder])
} else {};

local nodeExporterMixinHelmGrafanaDashboards = generateGrafanaDashboardConfigMaps(nodeExporterMixin);
local kubernetesMixinHelmGrafanaDashboards = generateGrafanaDashboardConfigMaps(kubernetesMixin);
local corednsMixinHelmGrafanaDashboards = generateGrafanaDashboardConfigMaps(corednsMixin);
local grafanaMixinHelmGrafanaDashboards = generateGrafanaDashboardConfigMaps(grafanaMixin);
local prometheusMixinHelmGrafanaDashboards = generateGrafanaDashboardConfigMaps(prometheusMixin);
local prometheusOperatorMixinHelmGrafanaDashboards = generateGrafanaDashboardConfigMaps(prometheusOperatorMixin);

local defaultDashboards =
  kubernetesMixinHelmGrafanaDashboards +
  nodeExporterMixinHelmGrafanaDashboards +
  corednsMixinHelmGrafanaDashboards +
  grafanaMixinHelmGrafanaDashboards +
  prometheusMixinHelmGrafanaDashboards +
  prometheusOperatorMixinHelmGrafanaDashboards;


local defaultAlerts = {
  'kubernetes-mixin-rules': kubernetesMixin.prometheusRules,
  'node-exporter-mixin-rules': nodeExporterMixin.prometheusRules,
  'coredns-mixin-rules': corednsMixin.prometheusRules,
  'grafana-mixin-rules': grafanaMixin.prometheusRules,
  'prometheus-mixin-rules': prometheusMixin.prometheusRules,
  'prometheus-operator-mixin-rules': prometheusOperatorMixin.prometheusRules,
};

defaultDashboards + defaultAlerts
