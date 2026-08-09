# Runtime architecture

```text
FFmpeg / Jellyfin
    | VA-API                 | Vulkan
libva + radeonsi_drv_video  Vulkan loader + RADV ICD
    \                       /
             libdrm
                |
       /dev/dri/renderD128
                |
       DSM amdgpu kernel module
```

## Package layout

```text
/var/packages/syno-amdgpu-runtime/target/
├── bin/                  # vainfo, vulkaninfo
├── lib/
│   ├── radeonsi_drv_video.so
│   ├── libvulkan_radeon.so
│   ├── libva*.so*
│   └── libdrm*.so*
└── etc/vulkan/icd.d/
    └── radeon_icd.x86_64.json
```

The package must not overwrite DSM's shared libraries. Consumers opt in with `LD_LIBRARY_PATH`, `LIBVA_DRIVERS_PATH`, and `VK_ICD_FILENAMES`; the final integration may install wrapper scripts instead of setting global system paths.

## Initial target

The first hardware target is DSM 7.2 `epyc7002` with an AMD Polaris GPU. It has a loaded `amdgpu` module, initialized UVD/VCE firmware, and `/dev/dri/renderD128`.
