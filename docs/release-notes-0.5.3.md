# Synology AMD+i915 Dual DRM and Runtime 0.5.3

## English

### Kernel 4.4.302 dual DRM stability and i915 monitoring

- Refreshed the combined AMDGPU, i915, and DRM modules for DSM 7.4 kernel 4.4.302 and 5.10.55. The drivers remain one compatible bundle, not separate AMD-only and Intel-only packages.
- Improved the legacy DRM device-close path and reservation-fence compatibility. DRM open/close, libdrm AMDGPU initialization/deinitialization, and GPU-information query/close smoke tests passed after a clean reboot.
- Restored the i915 PMU on kernel 4.4.302 by assigning an online CPU when the newer CPU hotplug state API is unavailable. A geminilake DSM 7.4 pilot exposed the i915 performance event source and reported GPU engines, frequency, and RC6 readings through `intel_gpu_top`.
- On DSM 7.4 kernel 4.4.302, the installer can create a missing `/sbin/depmod` link to `/usr/bin/kmod` and records it for safe removal. It does not overwrite an existing system command.
- Kernel 4.4.302 also gains a boot-time loader for AMDGPU's required experimental hardware option and i915; package-created hooks are tracked for safe removal.
- Kernel 4.4.302 remains experimental. The pilot logged `dma_fence_release` warnings; long-term stability and native Plex/Jellyfin or end-to-end hardware transcoding are not established by these tests. Diagnostic-only CPU-VM and scheduler options are not enabled in regular packages.

## 한국어

### 커널 4.4.302 Dual DRM 안정화 및 i915 모니터링

- DSM 7.4 커널 4.4.302 및 5.10.55용 AMDGPU·i915·DRM 통합 모듈을 갱신했습니다. AMD 전용과 Intel 전용으로 나누지 않고 하나의 호환 묶음으로 제공합니다.
- 구형 커널의 DRM 장치 종료 경로와 reservation fence 호환성을 개선했습니다. 재부팅 후 DRM 열기/닫기, libdrm AMDGPU 초기화/해제, GPU 정보 조회/닫기 스모크 테스트를 통과했습니다.
- 최신 CPU hotplug state API가 없는 커널에서도 온라인 CPU를 지정하도록 i915 PMU를 개선했습니다. geminilake DSM 7.4 파일럿에서 i915 성능 이벤트 소스가 나타났고, `intel_gpu_top`으로 GPU 엔진·주파수·RC6 값을 확인했습니다.
- DSM 7.4 커널 4.4.302에서 `/sbin/depmod`가 없으면 `/usr/bin/kmod`를 가리키는 링크를 만들고, 제거 시 안전하게 정리할 수 있도록 기록합니다. 기존 시스템 명령은 덮어쓰지 않습니다.
- 커널 4.4.302에서는 AMDGPU의 필수 실험적 하드웨어 옵션과 i915를 부팅 시 로드하며, 패키지가 만든 훅은 제거 시 안전하게 정리하도록 기록합니다.
- 커널 4.4.302는 여전히 실험적입니다. 파일럿에서 `dma_fence_release` 경고가 기록됐으며, 장시간 안정성이나 네이티브 Plex/Jellyfin 및 종단 간 하드웨어 트랜스코딩까지 검증한 것은 아닙니다. 진단 전용 CPU-VM·스케줄러 옵션은 정규 패키지에서 활성화하지 않습니다.
