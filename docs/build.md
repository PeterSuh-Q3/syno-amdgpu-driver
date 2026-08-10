# DSM 7.4 AMDGPU runtime SPK build

`build/ALL-PLATFORMS`에 등록된 DSM 7.4 x86_64 플랫폼을 대상으로 한다.
개별 결과물은 `dist/syno-amdgpu-runtime-7.4-<platform>.spk`이다.

## Build container prerequisites

기존 NVIDIA 빌드와 동일한 `dante90/syno-compiler:7.4` 컨테이너를 사용한다. 컨테이너에 아래 도구와 DSM 대상 LLVM이 있어야 한다.

- Meson, Ninja, pkg-config
- Rust/Cargo 및 `x86_64-unknown-linux-gnu` Rust target
- Mesa `radeonsi`가 링크할 DSM ABI용 LLVM과 `llvm-config`

`LLVM_CONFIG`는 대상 LLVM의 `llvm-config` 절대 경로로 지정한다. LLVM의 공유 라이브러리도 SPK의 `target/lib`에 함께 배치해야 한다. Mesa `radeonsi`는 LLVM 없이는 빌드할 수 없다.

## Sources and reproducibility

`build/versions.env`의 네 upstream archive를 내려받아 다음 이름으로 `sources/`에 푼다.

```text
sources/libdrm
sources/libva
sources/mesa
sources/amdgpu_top
```

각 archive의 SHA-256을 `build/sources.lock`에 기록한다. `RELEASE=1` 빌드는 `TODO`가 하나라도 있으면 중단한다.

## Build

```bash
./scripts/full-build.sh
```

기본 동시 빌드는 2개다. `full-build.sh`는 VM의 CPU 스레드를 동시 빌드 수로 나누어 플랫폼별 `-j` 값을 자동 설정한다. 예를 들어 12 스레드 VM에서는 2개 플랫폼을 동시에 빌드할 때 각각 `-j6`으로 제한한다.

```bash
PLATFORMS_FILE=build/ALL-PLATFORMS BUILD_JOBS=2 ./scripts/full-build.sh
```

빌드 중에는 플랫폼별 `llvm → libdrm → libva → mesa-prereqs → mesa → amdgpu_top → complete` 단계와 Ninja 카운트가 실시간 표시된다. 세부 로그는 `logs/`, 상태 파일은 `work/status/`에 남는다.

Mesa와 `amdgpu_top`은 패키지 내부의 라이브러리를 찾도록 RPATH/환경 래퍼를 사용한다. DSM의 `/usr/lib`를 수정하거나 덮어쓰지 않는다.
