# Synology AMD+i915 Dual DRM and Runtime 0.5.2

## English

This release provides two integrated DSM 7.4 packages. Each SPK contains the complete, unmodified DRM module archive for every platform in its kernel family, plus the shared AMD and Intel firmware and AMD userspace runtime. The installer selects the archive matching the NAS platform and kernel. The DRM archives are not split into AMD-only and Intel-only pieces.

Choose the SPK that matches the NAS kernel:

- **Kernel 5.10.55:** `epyc7002`, `epyc7003`, `geminilakenk`, `icelaked`, `r1000nk`, `v1000nk`.
- **Kernel 4.4.302:** `apollolake`, `broadwell`, `broadwellnk`, `broadwellnkv2`, `broadwellntbap`, `denverton`, `geminilake`, `purley`, `r1000`, `v1000`.

Both packages include AMD VA-API and RADV Vulkan userspace components, along with common AMD/i915 firmware. Reboot DSM after installation so the kernel modules, firmware, and DRM devices initialize cleanly.

**Kernel 4.4.302 is experimental:** Jellyfin/Plex automatic integration is disabled for this package. The presence of an asset in the SPK does not mean that every listed platform has been independently validated on physical hardware.

## 한국어

이번 릴리즈는 DSM 7.4용 통합 패키지 두 종을 제공합니다. 각 SPK에는 해당 커널 계열의 모든 지원 플랫폼에 대한 DRM 모듈 아카이브 원본과 공통 AMD/i915 펌웨어, AMD 사용자 공간 런타임이 포함됩니다. 설치기는 NAS의 플랫폼과 커널에 맞는 아카이브를 선택합니다. DRM 아카이브를 AMD 전용과 Intel 전용으로 분해하지 않습니다.

NAS 커널에 맞는 SPK를 선택하세요.

- **커널 5.10.55:** `epyc7002`, `epyc7003`, `geminilakenk`, `icelaked`, `r1000nk`, `v1000nk`.
- **커널 4.4.302:** `apollolake`, `broadwell`, `broadwellnk`, `broadwellnkv2`, `broadwellntbap`, `denverton`, `geminilake`, `purley`, `r1000`, `v1000`.

두 패키지 모두 AMD VA-API 및 RADV Vulkan 사용자 공간 구성요소와 공통 AMD/i915 펌웨어를 포함합니다. 커널 모듈·펌웨어·DRM 장치가 새로 초기화되도록 설치 후 DSM을 재부팅하세요.

**커널 4.4.302 패키지는 실험적입니다.** 이 패키지에서는 Jellyfin/Plex 자동 연동을 적용하지 않습니다. SPK에 자산이 포함되어 있다는 사실이 모든 플랫폼의 실기 검증 완료를 뜻하지는 않습니다.
