{% set style = pillar['types'][type] %}

{% if style == 'physical' %}
zeroize_{{ type }}:
  salt.parallel_runners:
    - runners:
{% for address in pillar['hosts'][type]['ipmi_addresses'] %}
        zeroize_{{ address }}:
          - name: state.orchestrate
          - kwarg:
              mods: orch/zeroize
              pillar:
                target: {{ address }}
                global: True
{% endfor %}
{% endif %}
