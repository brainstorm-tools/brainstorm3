#!/usr/bin/env bash

thirdparty_module_name='nwb-schema'

upstream_git_url='git://github.com/NeurodataWithoutBorders/nwb-schema'
upstream_git_branch='dev'
github_compare=true

snapshot_author_name='nwb-schema Upstream'
snapshot_author_email='neurodatawithoutborders@googlegroups.com'

snapshot_redact_cmd=''
snapshot_relative_path='schema'
snapshot_paths='
  core
  '

source "${BASH_SOURCE%/*}/../../utilities/maintenance/UpdateThirdPartyFromUpstream.sh"
update_from_upstream
