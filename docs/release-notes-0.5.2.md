# Synology AMD+i915 Dual DRM and Runtime 0.5.2

## English

**This is a standalone AMD+i915 Dual DRM + Runtime package, not merely an AMD userspace runtime.** It includes both `amdgpu.ko` and `i915.ko`, their bundled DRM dependencies, shared AMD/Intel firmware, and AMD userspace runtime.

For users of loader-based systems, the combined AMD+i915 DRM modules have commonly been available as part of an integrated module pack. This release offers those users a separately installable and manageable SPK instead. It also gives genuine Synology NAS owners a standalone option when their DSM kernel, platform, and hardware are compatible. Platform assets are included as listed below, but inclusion alone does not certify every model or hardware combination.

This release provides two integrated DSM 7.4 packages. Each SPK contains the complete, unmodified DRM module archive for every platform in its kernel family, plus shared AMD and Intel firmware and AMD userspace runtime. The installer selects the archive matching the NAS platform and kernel. The DRM archives are not split into AMD-only and Intel-only pieces.

Choose the SPK that matches the NAS kernel:

- **Kernel 5.10.55:** `epyc7002`, `epyc7003`, `geminilakenk`, `icelaked`, `r1000nk`, `v1000nk`.
- **Kernel 4.4.302:** `apollolake`, `broadwell`, `broadwellnk`, `broadwellnkv2`, `broadwellntbap`, `denverton`, `geminilake`, `purley`, `r1000`, `v1000`.

Both packages include AMD VA-API and RADV Vulkan userspace components, along with common AMD/i915 firmware. Reboot DSM after installation so the kernel modules, firmware, and DRM devices initialize cleanly.

**Kernel 4.4.302 is experimental:** Jellyfin/Plex automatic integration is disabled for this package. The presence of an asset in the SPK does not mean that every listed platform has been independently validated on physical hardware.

## 한국어

**이 패키지는 AMD 사용자 공간 런타임만이 아니라 `amdgpu.ko`와 `i915.ko`, 두 드라이버의 DRM 의존 모듈, 공통 AMD/i915 펌웨어, AMD 런타임을 포함하는 스탠드얼론 AMD+i915 Dual DRM 패키지입니다.**

헤놀로지 계열에서는 AMD+i915 통합 DRM 모듈이 기존 로더용 통합 모듈팩의 일부로 제공되는 경우가 많았습니다. 이번 릴리즈는 이를 별도로 설치하고 관리할 수 있는 SPK 선택지로 제공합니다. 또한 DSM 커널·플랫폼과 하드웨어가 호환되는 경우 **시놀로지 정품 NAS 사용자도** 사용할 수 있습니다. 단, 플랫폼 자산이 포함되었다는 이유만으로 모든 모델이나 하드웨어 조합의 호환성을 보장하지는 않습니다.

이번 릴리즈는 DSM 7.4용 커널 ABI별 통합 패키지 두 종을 제공합니다. 각 SPK는 해당 커널 계열의 전체 DRM 아카이브 원본과 공통 AMD/i915 펌웨어, AMD 사용자 공간 런타임을 포함합니다. 설치기는 NAS의 플랫폼과 커널에 맞는 아카이브를 선택하며, DRM 아카이브를 AMD 전용과 Intel 전용으로 분해하지 않습니다.

NAS 커널에 맞는 SPK를 선택하세요.

- **커널 5.10.55:** `epyc7002`, `epyc7003`, `geminilakenk`, `icelaked`, `r1000nk`, `v1000nk`.
- **커널 4.4.302:** `apollolake`, `broadwell`, `broadwellnk`, `broadwellnkv2`, `broadwellntbap`, `denverton`, `geminilake`, `purley`, `r1000`, `v1000`.

두 패키지 모두 AMD VA-API 및 RADV Vulkan 사용자 공간 구성요소와 공통 AMD/i915 펌웨어를 포함합니다. 커널 모듈·펌웨어·DRM 장치가 새로 초기화되도록 설치 후 DSM을 재부팅하세요.

**커널 4.4.302 패키지는 실험적입니다.** 이 패키지에서는 Jellyfin/Plex 자동 연동을 적용하지 않습니다. SPK에 자산이 포함되어 있다는 사실이 모든 플랫폼의 실기 검증 완료를 뜻하지는 않습니다.
