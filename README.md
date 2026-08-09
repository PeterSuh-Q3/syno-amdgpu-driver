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

## 검증 기준

```bash
ls -l /dev/dri/renderD*
LIBVA_DRIVER_NAME=radeonsi vainfo --display drm --device /dev/dri/renderD128
vulkaninfo --summary
ffmpeg -init_hw_device vaapi=amd:/dev/dri/renderD128 -hwaccel vaapi -i input.mp4 -f null -
```

`scripts/verify-runtime.sh`은 위 런타임을 설치한 뒤의 읽기 전용 점검을 자동화합니다.

## 개발 방향

1. DSM 7.2 x64 (`epyc7002`) toolchain으로 `libdrm`, `libva`, Mesa를 빌드한다.
2. Mesa는 Gallium `radeonsi`, VA-API, Vulkan `radv`를 포함한다.
3. SPK가 라이브러리와 ICD/VA driver 검색 경로를 자체 패키지 내부에 보존한다.
4. Jellyfin/컨테이너에서 `/dev/dri/renderD128` 권한과 환경 변수를 검증한다.

자세한 설계는 [docs/architecture.md](docs/architecture.md)를 참조하십시오.
