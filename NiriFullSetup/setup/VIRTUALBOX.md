# VirtualBox black screen (niri)

You're seeing niri and noctalia both running (`ps aux` confirmed both alive)
but nothing draws on screen. That's not a config bug — niri needs a real DRM
render device (`/dev/dri/renderD1xx`) with GBM support, and VirtualBox's
graphics driver frequently can't provide one, even with "3D Acceleration"
checked. That checkbox is an OpenGL-passthrough layer for old X11 apps, not
the same thing Wayland compositors need.

## 1. Host-side settings (VM powered off, in VirtualBox Manager)

- Settings -> Display -> **Graphics Controller: VBoxSVGA** (not VMSVGA or VGA)
- Settings -> Display -> **Enable 3D Acceleration**: on
- Video Memory: 128 MB
- `setup.sh` now installs `virtualbox-guest-utils` + enables `vboxservice`
  automatically when it detects VirtualBox (guest-side, already handled)

Reboot the VM after changing these.

## 2. Check if it actually worked

After reboot, from a TTY (not the black-screen VT):

```
ls /dev/dri/
```

- **See `renderD128` (or similar)?** → real render node exists, continue to step 3.
- **Only `card0`, no `renderDxxx`?** → VirtualBox is giving you a KMS device
  with no render node. GBM/EGL (what niri needs) won't work. This is the
  common case — skip to step 4.

## 3. Point niri at the render device explicitly

Add to `~/.config/niri/config.kdl`:

```
debug {
    render-drm-device "/dev/dri/renderD128"
}
```

(swap in whatever `ls /dev/dri/` actually showed)

## 4. If there's no render node at all

This is a real VirtualBox limitation, not something fixable from inside the
guest. Options, cheapest first:

- Try **VMSVGA** instead of VBoxSVGA (inconsistent across VirtualBox
  versions/host GPUs — some do expose a render node, most don't)
- Switch to a QEMU/KVM-backed hypervisor instead: **GNOME Boxes** or
  **virt-manager**, using `virtio-gpu` with `virgl`/3D acceleration enabled.
  This is the standard, reliable way to test Wayland compositors in a VM —
  niri, Sway, GNOME on Wayland all work out of the box on it.
- Test on real hardware instead of a VM.

skipped: scripting a definitive "does this render device support GBM" check
— that requires actually launching niri and reading its own crash output,
which only you can observe against the live VM.
