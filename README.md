# Synology AMDGPU Runtime

AMD GPU가 장착된 Synology DSM 7.x 시스템을 위한 사용자 공간 그래픽·미디어 런타임입니다.

이 프로젝트는 이미 커널에 로드된 `amdgpu` 모듈 위에 다음 구성요소를 DSM 패키지(SPK)로 제공하는 것을 목표로 합니다.

- AMD VA-API 드라이버: Mesa `radeonsi_drv_video.so`
- AMD Vulkan 드라이버: Mesa RADV와 `radv_icd.x86_64.json`
- 공통 런타임: `libdrm`, `libva`, Vulkan loader
- 진단 도구: `vainfo`, `vulkaninfo`

## 범위

지원 대상은 DRM render node (`/dev/dri/renderD*`)가 있고, 펌웨어 초기화까지 완료된 AMD GPU입니다. NVIDIA 커널 모듈이나 CUDA/ROCm은 범위에 포함하지 않습니다.

DSM의 FFmpeg 7/8 패키지는 Vulkan 및 VA-API 지원으로 빌드되어 있으므로, 이 패키지는 FFmpeg를 대체하지 않습니다. 설치 뒤 `LIBVA_DRIVER_NAME=radeonsi`로 FFmpeg/Jellyfin이 AMD VA-API를 이용할 수 있게 하는 것이 목적입니다.

Plex Media Server는 자체 Transcoder를 사용한다. 보안상 AMDGPU Runtime은 Plex 실행 파일을 자동으로 교체하거나 Plex 경로에 root 권한으로 쓰지 않는다. 이전 버전의 Plex 래퍼가 남아 있으면 업그레이드 시 정규 파일·심볼릭 링크 여부를 검증한 뒤 원본만 복원한다.

> 커널 4.4 환경의 VA-API는 실험적이다. `amdgpu_top`은 PATH에 등록하지 않으며, Plex/Jellyfin VA-API 문제로 kernel Oops·GPU hang이 발생하면 런타임을 제거하고 재부팅한 뒤 로그를 확보한다.

## 검증 기준

```bash
ls -l /dev/dri/renderD*
LIBVA_DRIVER_NAME=radeonsi vainfo --display drm --device /dev/dri/renderD128
vulkaninfo --summary
ffmpeg -init_hw_device vaapi=amd:/dev/dri/renderD128 -hwaccel vaapi -i input.mp4 -f null -
```

`scripts/verify-runtime.sh`은 위 런타임을 설치한 뒤의 읽기 전용 점검을 자동화합니다.

## 지원·검증 정책

DSM 7.4 실기 검증을 최우선으로 한다. 첫 릴리스는 현재 준비된 실기에서 Mesa `radeonsi` VA-API와 RADV Vulkan을 끝까지 검증한 뒤에만 만든다.

DSM 7.4에서 검증한 동일한 소스·패키징 구성을 DSM 7.3, 7.2, 7.1, 7.0 순으로 각 버전의 Synology toolchain으로 다시 빌드하고, 해당 DSM 실기 또는 동등한 검증 환경에서 확인한다. 하위 DSM 빌드는 선행 버전의 검증이 성공한 범위만 지원한다.

## 개발 방향

1. DSM 7.4 x64 (`epyc7002`) toolchain으로 `libdrm`, `libva`, Mesa를 빌드한다.
2. Mesa는 Gallium `radeonsi`, VA-API, Vulkan `radv`를 포함한다.
3. SPK가 라이브러리와 ICD/VA driver 검색 경로를 자체 패키지 내부에 보존한다.
4. DSM 7.4 실기에서 `vainfo`, `vulkaninfo`, FFmpeg 및 Jellyfin/컨테이너 트랜스코딩을 검증한다.
5. 성공한 구성을 DSM 7.0까지 버전별 toolchain으로 하향 빌드·검증한다.

자세한 설계는 [docs/architecture.md](docs/architecture.md)를 참조하십시오.

## SPK 빌드 골격

DSM 7.4 `epyc7002`용 첫 빌드는 `dante90/syno-compiler:7.4` 컨테이너에서 수행한다.

```bash
./scripts/run-spk-build.sh 7.4 epyc7002
```

빌드 정의는 `build/`에, DSM 패키지 메타데이터와 설치 스크립트는 `spk/`에 있다. Mesa의 `radeonsi`는 LLVM을 필요로 하므로, 빌드 컨테이너에는 DSM ABI용 `llvm-config`와 동적 `libLLVM`이 먼저 준비되어야 한다. 이 골격은 그 경로를 `LLVM_CONFIG`로 명시적으로 받으며, DSM 전역 라이브러리를 변경하지 않는다. 소스 준비와 실행 조건은 [빌드 가이드](docs/build.md)를 참조한다.
