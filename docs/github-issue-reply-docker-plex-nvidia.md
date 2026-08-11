# Docker Plex NVIDIA Transcoding — Suggested GitHub Issue Reply

First, could you confirm whether this is a **genuine Synology DS1823xs+**? The reported model, AMD Ryzen V1780B CPU, 4 cores, and 32 GB RAM match the official DS1823xs+ specification, but the screenshots alone cannot prove the hardware identity. Please verify that the serial number on the NAS chassis matches DSM and that the unit is registered to your Synology Account.

The `GPU: No device detected` entry in DSM Information Center is not, by itself, evidence of a problem or of an unsupported system. DSM may not display a third-party NVIDIA GPU there even when the NVIDIA driver works correctly.

Your screenshots strongly suggest that the host-side driver and RTX A2000 are working:

- `nvidia-smi` inside a CUDA test container detects the RTX A2000.
- Your Stable Diffusion container can use the GPU.
- Native Plex detects the GPU and performs hardware transcoding.

This points to a **Docker Plex container configuration issue**, rather than a GPU, driver, or NVENC hardware issue.

## Why `nvidia-smi` is not enough

The command below proves that the container can access NVIDIA management/CUDA functionality:

```bash
docker run --rm --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all \
  nvidia/cuda:12.9.0-base-ubuntu24.04 nvidia-smi
```

However, it does **not** prove that the Plex container has access to NVENC/NVDEC. NVIDIA Container Toolkit defaults to the `utility,compute` driver capabilities. Hardware video encoding and decoding require the additional `video` capability, which mounts the Video Codec SDK libraries such as `libnvidia-encode.so` and `libnvcuvid.so`. See the [NVIDIA Container Toolkit documentation](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/docker-specialized.html).

## Recommended Plex container settings

Make sure these settings are applied to the **actual Plex container**, not only to the CUDA test container:

```yaml
runtime: nvidia
environment:
  NVIDIA_VISIBLE_DEVICES: all
  NVIDIA_DRIVER_CAPABILITIES: compute,video,utility
```

`NVIDIA_DRIVER_CAPABILITIES: all` is also acceptable for testing.

After changing the container configuration, recreate or restart the Plex container. Also confirm that Plex Pass is active and that hardware acceleration is enabled in Plex.

## Checks to run inside the Plex container

Replace `plex` with your actual container name:

```bash
docker exec -it plex nvidia-smi
docker exec -it plex sh -c 'find / -name "libnvidia-encode.so*" 2>/dev/null'
docker exec -it plex sh -c 'find / -name "libnvcuvid.so*" 2>/dev/null'
```

If those two video libraries are missing, the Plex container does not have the NVIDIA `video` capability and will fall back to CPU transcoding.

## Summary

Native Plex hardware transcoding already proves that the RTX A2000, host driver, and NVENC are functional. The most likely missing piece is `NVIDIA_DRIVER_CAPABILITIES=video` on the Docker Plex container.
