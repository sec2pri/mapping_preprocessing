---
title: Failed {{ env.SOURCE }} processing for release {{ env.RELEASE_NUMBER }}
assignees: tabbassidaloii
labels: bug
name: Failed workflow issue template
about: Template for failing workflows
---

Processing failed for the [new release for {{ env.SOURCE }}]({{ env.URL_RELEASE }} ).

See [the action log](https://github.com/sec2pri/mapping_preprocessing/actions/runs/{{ env.GITHUB_RUN_ID }}) for more details.
