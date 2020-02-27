#!/usr/bin/env ruby

require 'kubeclient'
require 'lp'
require 'prometheus/api_client'
require 'pry'

# Some ActiveSupport helpers
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/hash/indifferent_access'

# Variables
results = ActiveSupport::HashWithIndifferentAccess.new
site_path = "http://prod8-prometheus-operator-prometheus.monitoring.svc.prod8:9090"

# Setup connection to Kubernetes
secrets_dir = ENV['TELEPRESENCE_ROOT'].nil? ? '' : ENV['TELEPRESENCE_ROOT']
secrets_dir = File.join(secrets_dir, '/var/run/secrets/kubernetes.io/serviceaccount/')
auth_options = {
  bearer_token_file: File.join(secrets_dir, 'token')
}
ssl_options = {}
if File.exists? File.join(secrets_dir, 'ca.crt')
  ssl_options[:ca_file] = File.join(secrets_dir, 'ca.crt')
end
kube = Kubeclient::Client.new(
  'https://kubernetes.default.svc',
  'v1',
  auth_options: auth_options,
  ssl_options: ssl_options
)
namespace = File.read File.join(secrets_dir, 'namespace')

# Setup connection to Prometheus
prom = Prometheus::ApiClient.client(url: site_path)

# Setup some helper lambdas
q = lambda { |query| prom.query(query: query) }
single_value = lambda { |query| q[query]['result'].first['value'].last }
multi_value = lambda { |query, name| q[query]['result'].map { |x| { name: x['metric'][name.to_s], value: x['value'].last } } }
fields_query = lambda { |query, fields| q[query]['result'].map { |x| x['metric'].slice(*fields.map{|y| y.to_s}) } }
enum_query = lambda { |query, values| values.map { |v| { name: v, value: single_value[query % {value: v}]} } }

binding.pry

# Get nodes

nodes = fields_query['kube_node_info', [:node]].map { |x| x['node'] }

###
# Kubernetes Node Information
###

# Check node cpu allocation
qry = %q[sum(kube_pod_container_resource_requests_cpu_cores{node="%{value}"}) / sum(kube_node_status_allocatable_cpu_cores{node="%{value}"})]
results[:node_cpu_allocation] = {
  title: 'Nodes with high CPU allocation',
  filter: '> 0.75',
  values: enum_query[qry, nodes],
}

# Check node memory allocation
qry = %q{sum(kube_pod_container_resource_requests_memory_bytes{node="%{value}"}) / sum(kube_node_status_allocatable_memory_bytes{node="%{value}"})}
results[:node_mem_allocation] = {
  title: 'Nodes with high memory allocation',
  filter: '> 0.75',
  values: enum_query[qry, nodes],
}

###
# Kubernetes Pod Info
###

# Pods that are in state != [Ready, Completed]
qry = 'kube_pod_status_phase{phase!~"(Completed|Succeeded|Running)"}'
results[:pods_unready] = {
  title: "Unready pods",
  values: fields_query[qry, [:pod, :phase]]
}

# Pods that have restarted in the past 24h
qry = 'floor(delta(kube_pod_container_status_restarts_total[24h])) != 0'
results[:pod_restarts] = {
  title: "Pods that have restarted in the past 24h",
  values: multi_value[qry, :pod],
}

# Nodes with high load (5m?)
# Deployments with mismatching requested v ready

binding.pry
#lp results