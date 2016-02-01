{% import_yaml "owncloud/defaults.yaml" as defaults %}
{% from "owncloud/docker-env.jinja" import envs with context %}

{% set images = [] %}
{% for docker_name in salt['pillar.get']('owncloud:dockers', {}) %}
{% set docker = salt['pillar.get']('owncloud:dockers:' ~ docker_name,
                                   default=defaults.docker, merge=True) %}
{% set docker_image = docker.image if ':' in docker.image else docker.image ~ ':latest' %}
{% do images.append(docker_image) if docker_image not in images %}

{% set links = [] %}
{% do links.append(docker.database.link ~ ':' ~ docker.database.type) if 'link' in docker.database %}

owncloud-docker_{{ docker_name }}_running:
  dockerng.running:
    - name: {{ docker_name }}
    - image: {{ docker.image }}
    - binds:
      - {{ docker.data_dir }}:{{ docker.docker_data_dir }}
    {% if links %}
    - links:
      {% for link in links %}
      - {{ link }}
      {% endfor %}
    {% endif %}
    - ports:
      - {{ docker.docker_http_port }}
    - require:
      - cmd: owncloud-docker-image_{{ docker_image }}
      {% if 'link' in docker.database %}
      - dockerng: {{ docker.database.link }}
      {% endif %}
    - environment:
      {{ envs(docker)|indent(6)}}

owncloud-docker_{{ docker_name }}_volume:
  file.directory:
    - name: {{ docker.data_dir }}
    - makedirs: True
#  module.run:
#    - name: file.set_selinux_context
#    - path: {{ docker.data_dir }}
#    - type: svirt_sandbox_file_t
#    - require:
#      - file: {{ docker.data_dir }}
    - require_in:
      - dockerng: {{ docker_name }}
{% endfor %}

{% for image in images %}
owncloud-docker-image_{{ image }}:
  cmd.run:
    - name: docker pull {{ image }}
    - unless: '[ $(docker images -q {{ image }}) ]'
{% endfor %}
