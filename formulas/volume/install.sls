include:
  - /formulas/openstack/common/repo
  - /formulas/ceph/common/repo

{% if grains['os_family'] == 'Debian' %}

volume_packages:
  pkg.installed:
    - pkgs:
      - python3-openstackclient
      - cinder-volume
      - python3-memcache
      - ceph-common
      - python3-rbd
      - python3-rados

{% elif grains['os_family'] == 'RedHat' %}

volume_packages:
  pkg.installed:
    - pkgs:
      - openstack-cinder
      - python3-openstackclient
      - python3-memcached
      - ceph-common
      - python3-rbd
      - python3-rados

{% endif %}
