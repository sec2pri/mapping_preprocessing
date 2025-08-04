---
title: Update {{ env.SOURCE }} to release {{ env.RELEASE_NUMBER }}
assignees: tabbassidaloii
labels: new release
name: Update source issue
about: Template for upstream updates.
---
# [New release for {{ env.SOURCE }}]({{ env.URL_RELEASE }}) available.

## What's changed
- ID pairs changed or added in new release: **{{ env.ADDED }}**
- ID pairs removed in new data version: **{{ env.REMOVED }}**
- Change rate: **{{ env.CHANGE }}** % in current version (100 * changed mapping pairs / total mapping pairs)

Date of release: {{ env.DATE_NEW }}.

## Retrieve processed data

The processed data is available in [the action log page](https://github.com/sec2pri/mapping_preprocessing/actions/runs/{{ env.GITHUB_RUN_ID }}) as an artifact.

