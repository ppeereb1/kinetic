{% set type = pillar['type'] %}

## Bootstrap physical hosts
rotate_{{ type }}:
  salt.state:
    - tgt: 'salt'
    - sls:
      - orch/states/rotate
    - pillar:
          type: {{ type }}
    - require:
      - pxe_setup

delete_{{ type }}_key:
  salt.wheel:
    - name: key.delete
    - match: '{{ type }}*'
    - require:
      - rotate_{{ type }}

  {% for address in pillar['hosts'][type]['ipmi_addresses'] %}
wait_for_{{ type }}_{{ address }}_hostname_assignment:
  salt.wait_for_event:
    - name: salt/job/*/ret/pxe
    - event_id: fun
    - id_list:
      - mine.send
    - timeout: 300
    - require:
      - rotate_{{ type }}
  {% endfor %}

provision_{{ type }}:
  salt.runner:
    - name: state.orchestrate
    - mods: orch/provision

{% endfor %}

## Bootstrap virtual hosts

##provision_virtual:
##  salt.runner:
##    - name: state.orchestrate
##    - mods: orch/virtual
##    - require:
##      - provision_controller
