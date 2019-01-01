uca:
  pkgrepo.managed:
    - humanname: Ubuntu Cloud Archive - Rocky
    - name: deb http://ubuntu-cloud.archive.canonical.com/ubuntu bionic-updates/rocky main
    - file: /etc/apt/sources.list.d/cloudarchive-rocky.list
    - keyid: ECD76E3E
    - keyserver: keyserver.ubuntu.com

ceph_repo:
  pkgrepo.managed:
    - humanname: Ceph Mimic
    - name: deb https://download.ceph.com/debian-mimic/ bionic main
    - file: /etc/apt/sources.list.d/ceph.list
    - key_url: https://download.ceph.com/keys/release.asc

update_packages_uca:
  pkg.uptodate:
    - refresh: true
    - onchanges:
      - pkgrepo: uca
    - dist_upgrade: True
update_packages_ceph:
  pkg.uptodate:
    - refresh: true
    - onchanges:
      - ceph_repo
    - dist_upgrade: True

cinder_packages:
  pkg.installed:
    - pkgs:
      - cinder-api
      - cinder-scheduler
      - python-openstackclient
      - cinder-volume
      - python-memcache

install_ceph:
  pkg.installed:
    - name: ceph-common
    - require:
      - pkgrepo: ceph_repo