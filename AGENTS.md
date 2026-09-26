# Repository build and release instructions

## Current release objective

For the next full build, the supported success target is **AMD hardware transcoding inside a Docker container on DSM**. Do not treat native Plex/Jellyfin playback or transcoding on kernel 4.4 DSM as a required success case, and do not claim that a successful package build alone proves hardware transcoding works.

Docker changes the userspace environment, not the DSM host kernel. The host must still boot a compatible `amdgpu.ko`, load the matching firmware, and expose a working `/dev/dri/renderD*` node. The container must receive the render device with usable permissions and have a compatible AMD VA-API userspace driver and FFmpeg build. Test and report these host and container layers separately.

## Full-build pattern

1. Inspect the target branch, package version, platform matrices, pinned asset/source checksums, and current build scripts before starting. Preserve pre-existing user changes; never overwrite or silently include unrelated dirty files in a release build.
2. Build the userspace runtime from source for the complete declared platform matrix using the repository's supported build path (`scripts/full-build.sh` and its builder/toolchain prerequisites). Then assemble the integrated kernel-family packages using the applicable universal packaging scripts (`scripts/build-driver-kernel5-universal.sh` and `scripts/build-driver-kernel4-universal.sh`) when their required base runtime SPK and pinned driver assets are available. Do not substitute a repack-only operation for a requested full source build.
3. Keep kernel ABI packages separate: kernel 5.10.55 and kernel 4.4.302 DRM modules are not interchangeable. Preserve each platform's complete `*-drm.tgz` bundle; do not split AMD and i915 modules. Verify package architecture, DSM/kernel family, version, module bundles, firmware, and checksums before release.
4. Validate the package in a Docker-based test on the intended DSM host. Confirm the host render node and permissions, confirm the container can access that node and load the AMD VA-API driver, and run a real FFmpeg hardware-encode/transcode test. Logs must show VA-API initialization and hardware video processing (not `-codec copy` or software-only encoding). Record the exact container image, FFmpeg command/version, device mapping, and result. A synthetic test that does not finish or does not show GPU video processing is not a pass.
5. Report kernel-4 native-app limitations separately. A Docker-only pass does not establish native Plex/Jellyfin compatibility, and a package/build success without the Docker transcode test is not a validated release.

## Dual DRM kernel-4 full-build procedure

The full AMDGPU + i915 kernel-module build is maintained in the separate [`redpill-dual-drm-backports`](https://github.com/PeterSuh-Q3/redpill-dual-drm-backports) repository. Do not mistake this runtime repository's `scripts/full-build.sh` or its SPK repack workflow for that module build.

For the requested all-platform kernel-4.4.302 run, dispatch this exact workflow:

```text
.github/workflows/step6-dual-drm-all-platforms-44302.yml
Workflow: [STEP6] Dual DRM 통합 빌드 (ALL platforms 4.4.302, DSM 7.2/7.3/7.4)
Workflow ID: 295831325 (IDs can change if the workflow is recreated; resolve by path/name before dispatch.)
```

Leave both `platforms` and `versions` inputs empty to request the complete matrix: ten kernel-4 platforms across DSM 7.2, 7.3, and 7.4 (30 matrix jobs). Do not substitute the separate DSM-7.4-only STEP6 workflow unless the user explicitly changes scope. The workflow uploads module artifacts and has a single-writer `module-output` branch aggregation job; after completion, inspect the run conclusion, all matrix job results, artifact contents, and the `module-output` update. A green workflow conclusion alone is not proof of an on-NAS Docker hardware-transcoding pass.

### Required temporary visibility sequence

1. Before dispatch, inspect the **target** repository `PeterSuh-Q3/redpill-dual-drm-backports`. If it is private, change it to public and verify that state before starting the workflow. Do not change this runtime repository's visibility as a substitute.
2. Dispatch the full workflow above and monitor it to a terminal conclusion. Blank inputs mean the full 30-job matrix.
3. Whether the run succeeds or fails, once it is terminal change `redpill-dual-drm-backports` back to private and verify the private state. Only then report the build outcome and provide the run link.

Repository visibility is an administrative operation. GitHub's default `GITHUB_TOKEN` must not be assumed to have permission to change it; use the authenticated owner/admin session. If automating visibility restoration, use a narrowly scoped credential with repository-administration permission and a completion/finalization path for both success and failure, plus a manual recovery path for cancellation, runner loss, or finalizer failure. Never put credentials in source, logs, or artifacts.

**Visibility warning:** while public, the target repository's source, issues, Actions metadata/logs, and public release assets can be exposed. Making it private later does not undo that exposure or preserve public download access to private release assets. Do not publish or advertise release artifacts during the temporary public interval unless that exposure is intended.

### Acceptance and reporting

This module workflow compiles kernel modules; it does not itself prove media transcoding. For this project, the functional acceptance target is AMD hardware transcoding **inside a Docker container on the DSM host**, not native Plex/Jellyfin transcoding on kernel 4.4 DSM. After module installation and reboot, separately verify a host `amdgpu.ko` load and `/dev/dri/renderD*`, pass the render device and permissions into the container, confirm its AMD VA-API driver initializes, and complete an FFmpeg hardware transcode with evidence of hardware video processing (not stream copy or software encoding). Record the module workflow result and container test result as distinct outcomes. A Docker-only pass does not establish native-app compatibility.

## General safeguards

- Read the target scripts and workflow before changing or invoking them; repository instructions and build behavior must match the current implementation.
- Keep generated sources, build trees, logs, and `dist/` outputs distinct from tracked source changes. Preserve failure logs and workspaces needed for diagnosis.
- Do not commit, push, publish, change repository visibility, or start a remote build unless that action is explicitly requested for the current task.
- Never describe VA-API availability, device-node visibility, or successful package installation alone as proof of hardware transcoding.
