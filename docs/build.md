# DSM 7.4 epyc7002 SPK build

이 초기 프로파일은 DSM 7.4 `epyc7002`만 대상으로 한다. 결과물은 `dist/syno-amdgpu-runtime-7.4-epyc7002.spk`이다.

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
LLVM_CONFIG=/path/to/target/llvm-config ./scripts/run-spk-build.sh 7.4 epyc7002
```

Mesa와 `amdgpu_top`은 패키지 내부의 라이브러리를 찾도록 RPATH/환경 래퍼를 사용한다. DSM의 `/usr/lib`를 수정하거나 덮어쓰지 않는다.
