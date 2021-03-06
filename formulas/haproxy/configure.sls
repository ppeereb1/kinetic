include:
  - /formulas/haproxy/install
  - /formulas/common/base

{% if grains['spawning'] == 0 %}

spawnzero_complete:
  event.send:
    - name: {{ grains['type'] }}/spawnzero/complete
    - data: "{{ grains['type'] }} spawnzero is complete."

{% endif %}

### Gateway configuration
{% if salt['pillar.get']('danos:enabled', False) == True %}
set haproxy group:
  danos.set_resourcegroup:
    - name: haproxy-group
    - type: address-group
    - description: list of current haproxy servers
    - values:
      - {{ salt['network.ipaddrs'](cidr=pillar['networking']['subnets']['management'])[0] }}
    - username: {{ pillar['danos']['username'] }}
    - password: {{ pillar['danos_password'] }}
  {% if salt['pillar.get']('danos:endpoint', "gateway") == "gateway" %}
    - host: {{ grains['ip4_gw'] }}
  {% else %}
    - host: {{ pillar['danos']['endpoint'] }}
  {% endif %}

set nfs group:
  danos.set_resourcegroup:
    - name: manila-share-servers
    - type: address-group
    - description: list of current nfs-ganesha servers
    - values:
  {% for host, addresses in salt['mine.get']('role:share', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
    {%- for address in addresses -%}
      {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
      - {{ address }}
      {%- endif -%}
    {%- endfor -%}
  {% endfor %}
    - username: {{ pillar['danos']['username'] }}
    - password: {{ pillar['danos_password'] }}
  {% if salt['pillar.get']('danos:endpoint', "gateway") == "gateway" %}
    - host: {{ grains['ip4_gw'] }}
  {% else %}
    - host: {{ pillar['danos']['endpoint'] }}
  {% endif %}

set haproxy static-mapping:
  danos.set_statichostmapping:
    - name: {{ pillar['haproxy']['dashboard_domain'] }}
    - address: {{ salt['network.ipaddrs'](cidr=pillar['networking']['subnets']['management'])[0] }}
    - aliases:
      - {{ pillar['haproxy']['console_domain'] }}
      - {{ pillar['haproxy']['docs_domain'] }}
    - username: {{ pillar['danos']['username'] }}
    - password: {{ pillar['danos_password'] }}
  {% if salt['pillar.get']('danos:endpoint', "gateway") == "gateway" %}
    - host: {{ grains['ip4_gw'] }}
  {% else %}
    - host: {{ pillar['danos']['endpoint'] }}
  {% endif %}
{% endif %}

{% if grains['os_family'] == 'RedHat' %}
haproxy_connect_any:
  selinux.boolean:
    - value: True
    - persist: True
    - require:
      - sls: /formulas/haproxy/install
{% endif %}

{% for domain in pillar['haproxy']['tls_domains'] %}

acme_{{ domain }}:
  acme.cert:
    - name: {{ domain }}
    - email: {{ pillar['haproxy']['tls_email'] }}
    - renew: 14
{% if salt['pillar.get']('danos:enabled', False) == True %}
    - require:
      - danos: set haproxy group
      - danos: set haproxy static-mapping
{% endif %}

create_master_pem_{{ domain }}:
  cmd.run:
    - name: cat /etc/letsencrypt/live/{{ domain }}/fullchain.pem /etc/letsencrypt/live/{{ domain }}/privkey.pem > /etc/letsencrypt/live/{{ domain }}/master.pem
    - creates: /etc/letsencrypt/live/{{ domain }}/master.pem
    - require:
      - acme: acme_{{ domain }}

{% endfor %}

/etc/haproxy/haproxy.cfg:
  file.managed:
    - source: salt://formulas/haproxy/files/haproxy.cfg
    - template: jinja
{% if salt['pillar.get']('syslog_url', False) == False %}
  {% for host, addresses in salt['mine.get']('role:graylog', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
    {% for address in addresses %}
      {% if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
    - context:
        syslog: {{ address }}:5514
      {% endif %}
    {% endfor %}
  {% endfor %}
{% endif %}
    - defaults:
{% if salt['pillar.get']('syslog_url', False) != False %}
        syslog: {{ pillar['syslog_url'] }}
{% else %}
        syslog: 127.0.0.1:5514
{% endif %}
        seamless_reload: stats socket /var/run/haproxy.sock mode 600 expose-fd listeners level user
        hostname: {{ grains['id'] }}
        management_ip_address: {{ salt['network.ipaddrs'](cidr=pillar['networking']['subnets']['management'])[0] }}
        dashboard_domain: {{ pillar['haproxy']['dashboard_domain'] }}
        console_domain:  {{ pillar['haproxy']['console_domain'] }}
        docs_domain:  {{ pillar['haproxy']['docs_domain'] }}
        keystone_hosts: |
          {%- for host, addresses in salt['mine.get']('type:keystone', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}{{ pillar['openstack_services']['keystone']['configuration']['public_endpoint']['port'] }} check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        glance_api_hosts: |
          {%- for host, addresses in salt['mine.get']('type:glance', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}{{ pillar['openstack_services']['glance']['configuration']['public_endpoint']['port'] }} check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        nova_compute_api_hosts: |
          {%- for host, addresses in salt['mine.get']('type:nova', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}{{ pillar['openstack_services']['nova']['configuration']['public_endpoint']['port'] }} check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        nova_metadata_api_hosts: |
          {%- for host, addresses in salt['mine.get']('type:nova', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}:8775 check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        placement_api_hosts: |
          {%- for host, addresses in salt['mine.get']('type:placement', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}:8778 check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        nova_spiceproxy_hosts: |
          {%- for host, addresses in salt['mine.get']('type:nova', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}:6082 check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        dashboard_hosts: |
          {%- for host, addresses in salt['mine.get']('type:horizon', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}:80 check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        docs_hosts: |
          {%- for host, addresses in salt['mine.get']('type:antora', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}:80 check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        neutron_api_hosts: |
          {%- for host, addresses in salt['mine.get']('type:neutron', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}{{ pillar['openstack_services']['neutron']['configuration']['public_endpoint']['port'] }} check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        heat_api_hosts: |
          {%- for host, addresses in salt['mine.get']('type:heat', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}{{ pillar['openstack_services']['heat']['configuration']['public_endpoint']['port'] }} check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        heat_api_cfn_hosts: |
          {%- for host, addresses in salt['mine.get']('type:heat', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}{{ pillar['openstack_services']['heat']['configuration']['public_endpoint_cfn']['port'] }} check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        cinder_api_hosts: |
          {%- for host, addresses in salt['mine.get']('type:cinder', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}{{ pillar['openstack_services']['cinder']['configuration']['public_endpoint']['port'] }} check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        designate_api_hosts: |
          {%- for host, addresses in salt['mine.get']('type:designate', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}{{ pillar['openstack_services']['designate']['configuration']['public_endpoint']['port'] }} check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        swift_hosts: |
          {%- for host, addresses in salt['mine.get']('type:swift', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}{{ pillar['openstack_services']['swift']['configuration']['public_endpoint']['port'] }} check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        zun_api_hosts: |
          {%- for host, addresses in salt['mine.get']('type:zun', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}{{ pillar['openstack_services']['zun']['configuration']['public_endpoint']['port'] }} check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        zun_wsproxy_hosts: |
          {%- for host, addresses in salt['mine.get']('type:zun', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}:6784 check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        barbican_hosts: |
          {%- for host, addresses in salt['mine.get']('type:barbican', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}:9311 check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        magnum_hosts: |
          {%- for host, addresses in salt['mine.get']('type:magnum', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}:9511 check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        sahara_hosts: |
          {%- for host, addresses in salt['mine.get']('type:sahara', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}:8386 check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        manila_hosts: |
          {%- for host, addresses in salt['mine.get']('type:manila', 'network.ip_addrs', tgt_type='grain') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}:8786 check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
        mysql_hosts: |-
          {%- for host, addresses in salt['mine.get']('G@type:mysql and G@spawning:0', 'network.ip_addrs', tgt_type='compound') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}:3306 check inter 2000 rise 2 fall 5
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}
          {%- for host, addresses in salt['mine.get']('G@type:mysql and not G@spawning:0', 'network.ip_addrs', tgt_type='compound') | dictsort() %}
            {%- for address in addresses -%}
              {%- if salt['network']['ip_in_subnet'](address, pillar['networking']['subnets']['management']) %}
          server {{ host }} {{ address }}:3306 check inter 2000 rise 2 fall 5 backup
              {%- endif -%}
            {%- endfor -%}
          {%- endfor %}

haproxy_service_watch:
  service.running:
    - name: haproxy
    - reload: true
    - watch:
      - file: /etc/haproxy/haproxy.cfg
