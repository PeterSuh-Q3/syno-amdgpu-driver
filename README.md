# Synology AMD+i915 Dual DRM and Runtime

**DSM 7.4용 통합 AMD+i915 DRM 드라이버와 AMD GPU 런타임을 제공합니다.** 플랫폼마다 SPK를 따로 설치하는 대신, 커널 ABI별 통합 SPK 하나가 해당 커널 계열의 모든 지원 플랫폼용 원본 DRM 묶음과 공통 AMD/i915 펌웨어를 포함합니다. 설치기는 NAS의 플랫폼과 커널을 확인해 일치하는 DRM 묶음만 적용합니다.

두 커널 ABI는 호환되지 않으므로 각각 별도 SPK로 제공합니다. 한 번의 GitHub 릴리즈에서 알맞은 파일을 선택하세요.

| SPK | DSM 7.4 커널 | 포함 플랫폼 |
|---|---|---|
| `...-kernel5.10.55.spk` | 5.10.55 | `epyc7002`, `epyc7003`, `geminilakenk`, `icelaked`, `r1000nk`, `v1000nk` |
| `...-kernel4.4.x.spk` | 4.4.302 | `apollolake`, `broadwell`, `broadwellnk`, `broadwellnkv2`, `broadwellntbap`, `denverton`, `geminilake`, `purley`, `r1000`, `v1000` |

각 `*-drm.tgz` 모듈 묶음은 분해하거나 AMD/i915별로 필터링하지 않고 원형 그대로 패키지에 담습니다. 패키지는 모듈 및 펌웨어 입력의 SHA-256을 검증하며, 설치 후 DSM 재부팅이 필요합니다. Kernel 4.4.x의 미디어 서버 자동 연동은 비활성화되어 있고 VA-API는 실험적입니다.

사용자 공간 런타임은 AMD VA-API/Vulkan 구성요소를 제공합니다.

- AMD VA-API 드라이버: Mesa `radeonsi_drv_video.so`
- AMD Vulkan 드라이버: Mesa RADV와 `radv_icd.x86_64.json`
- 공통 런타임: `libdrm`, `libva`, Vulkan loader
- 진단 도구: `vainfo`, `vulkaninfo`
- 커널 5.10.55 및 4.4.302 DRM 모듈: 위 표의 플랫폼별 전체 묶음. 설치기가 실행 중인 커널/플랫폼과 일치하는 묶음만 적용합니다.
- 펌웨어: [`tcrp-modules/firmware/common`](https://github.com/PeterSuh-Q3/tcrp-modules/tree/main/firmware/common)의 AMDGPU 및 i915 펌웨어

AMD GPU의 사용률·VRAM·온도 등을 DSM 플로팅 창에서 확인하려면 별도 프로젝트인 [Synology GPU Monitor](https://github.com/PeterSuh-Q3/syno-gpu-monitor)의 AMD 패키지를 설치하세요. 패키지와 화면 예시는 [통합 GPU Monitor 릴리즈 페이지](https://github.com/PeterSuh-Q3/syno-gpu-monitor/releases/tag/gpu-monitors-2026.09.24)에서 받을 수 있습니다. AMDGPU Runtime과 GPU Monitor는 서로 독립적으로 설치·동작합니다.

![Synology AMD GPU Monitor showing GPU telemetry and the amdgpu_top console](docs/amd-gpu-monitor.png)

GPU 사용률·VRAM·온도 모니터링(`amdgpu_top`)이 필요하면 별도 패키지인 [syno-amdgpu-top](https://github.com/PeterSuh-Q3/syno-amdgpu-top)을 설치하세요. `amdgpu_top`은 Mesa/VA-API에 의존하지 않는 독립 도구라 이 런타임과 분리되어 있습니다.

## 범위

지원 대상은 DRM render node (`/dev/dri/renderD*`)가 있고, 펌웨어 초기화까지 완료된 AMD GPU입니다. NVIDIA 커널 모듈이나 CUDA/ROCm은 범위에 포함하지 않습니다.

DSM의 FFmpeg 7/8 패키지는 Vulkan 및 VA-API 지원으로 빌드되어 있으므로, 이 패키지는 FFmpeg를 대체하지 않습니다. 설치 뒤 `LIBVA_DRIVER_NAME=radeonsi`로 FFmpeg/Jellyfin이 AMD VA-API를 이용할 수 있게 하는 것이 목적입니다.

Plex Media Server는 자체 Transcoder를 사용한다. 보안상 AMDGPU Runtime은 Plex 실행 파일을 자동으로 교체하거나 Plex 경로에 root 권한으로 쓰지 않는다. 이전 버전의 Plex 래퍼가 남아 있으면 업그레이드 시 정규 파일·심볼릭 링크 여부를 검증한 뒤 원본만 복원한다.

> 커널 4.4 환경의 VA-API는 실험적이다. 이 kernel4.4.x 패키지는 Jellyfin/Plex 하드웨어 트랜스코딩 연동 자체를 적용하지 않으며, kernel Oops·GPU hang이 발생하면 런타임을 제거하고 재부팅한 뒤 로그를 확보한다.

AMD GPU의 DRM render node(`renderD128`의 PCI vendor가 `0x1002`)가 없는 NAS에서는 SPK 자체는 설치할 수 있지만, 런타임은 no-op으로 동작한다. 따라서 Intel iGPU만 있는 NAS도 Jellyfin/Plex 설정이나 전역 라이브러리 경로를 변경하지 않는다.

## 설치 후 재부팅

통합 Driver + Runtime SPK를 설치하거나 업그레이드한 뒤에는 DSM을 한 번 재부팅하세요. 설치 직후 모듈이 로드되고 render node가 보이더라도, 부팅 과정에서 커널 모듈·AMD/i915 펌웨어·DRM 장치 노드가 새로 초기화된 상태를 기준으로 GPU 정보와 하드웨어 트랜스코딩을 확인해야 합니다. 재부팅 후 `/dev/dri/renderD*`가 생성됐는지, 해당 미디어 서버 계정이 사용할 render node 권한을 갖는지 확인한 다음 재생 테스트를 진행하세요.

## 검증 기준

```bash
ls -l /dev/dri/renderD*
LIBVA_DRIVER_NAME=radeonsi vainfo --display drm --device /dev/dri/renderD128
vulkaninfo --summary
ffmpeg -init_hw_device vaapi=amd:/dev/dri/renderD128 -hwaccel vaapi -i input.mp4 -f null -
```

`scripts/verify-runtime.sh`은 위 런타임을 설치한 뒤의 읽기 전용 점검을 자동화합니다.

## 지원 범위

현재 패키지는 DSM 7.4만 대상으로 합니다. 커널 5.10.55와 4.4.302는 모듈 ABI가 달라 SPK가 분리되어 있습니다. 패키지에 플랫폼 자산이 포함되어 있다는 사실과 그 플랫폼의 실기 검증 완료 여부는 구분해야 합니다. DSM 7.3, 7.2, 7.1, 7.0 지원은 별도 toolchain 빌드와 검증 후에만 추가합니다.

## 개발 방향

1. DSM 7.4 x64 (`epyc7002`) toolchain으로 `libdrm`, `libva`, Mesa를 빌드한다.
2. Mesa는 Gallium `radeonsi`, VA-API, Vulkan `radv`를 포함한다.
3. SPK가 라이브러리와 ICD/VA driver 검색 경로를 자체 패키지 내부에 보존한다.
4. DSM 7.4 실기에서 `vainfo`, `vulkaninfo`, FFmpeg 및 Jellyfin/컨테이너 트랜스코딩을 검증한다.
5. 성공한 구성을 DSM 7.0까지 버전별 toolchain으로 하향 빌드·검증한다.

자세한 설계는 [docs/architecture.md](docs/architecture.md)를 참조하십시오.

커널 계열별 통합 SPK의 DRM 보존 정책, 자산 체크섬, 설치·복구 동작은 [Driver + Runtime 설계](docs/standalone-driver-design.md)를 참조하십시오.

## SPK 빌드 골격

DSM 7.4의 커널별 통합 SPK는 `dante90/syno-compiler:7.4` 컨테이너에서 빌드한다.

```bash
./scripts/build-driver-kernel5-universal.sh
./scripts/build-driver-kernel4-universal.sh
```

두 스크립트는 DSM 7.4의 각 커널 ABI에서 지원하는 모든 플랫폼의 DRM 아카이브를 원본 그대로 포함하고 공통 AMD/i915 펌웨어를 한 번씩 추가한다. 빌드 정의와 자산 체크섬은 `build/`에, DSM 패키지 메타데이터와 설치 스크립트는 `spk/`에 있다. 상세한 소스 준비와 빌드 조건은 [빌드 가이드](docs/build.md)를 참조한다.
