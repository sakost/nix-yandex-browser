# nix-yandex-browser

Nix flake for Yandex Browser on NixOS.

## Disclaimer

This is an **unofficial** community packaging of Yandex Browser for Nix/NixOS.
Yandex Browser is proprietary software developed by Yandex.
This repository only contains Nix expressions for packaging; it does not distribute the browser itself.

## Features

- Packages the **stable** release directly from the official Yandex apt repository
- Wayland support out of the box (auto-detected via `WAYLAND_DISPLAY`)
- Properly patched with `patchelf` — no FHS hacks or `buildFHSEnv`
- Provided as a flake with a ready-to-use overlay

## Usage

Try it without installing:

```bash
nix run github:sakost/nix-yandex-browser
```

Or open a shell with the browser available:

```bash
nix shell github:sakost/nix-yandex-browser
```

## Installation

### NixOS (flake)

Add the flake input and include the package in your system configuration:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-yandex-browser.url = "github:sakost/nix-yandex-browser";
  };

  outputs = { nixpkgs, nix-yandex-browser, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            nix-yandex-browser.packages.${pkgs.system}.yandex-browser
          ];
        })
      ];
    };
  };
}
```

### Home Manager

```nix
# In your Home Manager configuration
{ pkgs, inputs, ... }: {
  home.packages = [
    inputs.nix-yandex-browser.packages.${pkgs.system}.yandex-browser
  ];
}
```

### Overlay

Apply the overlay to get `yandex-browser` in your `pkgs`:

```nix
{
  nixpkgs.overlays = [
    nix-yandex-browser.overlays.default
  ];

  # Then use it anywhere:
  environment.systemPackages = [ pkgs.yandex-browser ];
}
```

## Unfree Software Notice

Yandex Browser is proprietary software. You need to allow unfree packages for it to build.

If you use the flake directly (`nix run` / `nix shell`), this is handled automatically.

For system-wide or Home Manager installs, set one of:

```nix
# Allow all unfree packages
nixpkgs.config.allowUnfree = true;

# Or allow only this package
nixpkgs.config.allowUnfreePredicate = pkg:
  builtins.elem (lib.getName pkg) [ "yandex-browser-stable" ];
```

## License

The Nix packaging code in this repository is licensed under the [MIT License](LICENSE).

Yandex Browser itself is proprietary software subject to the
[Yandex License Agreement](https://yandex.ru/legal/browser_agreement/).
