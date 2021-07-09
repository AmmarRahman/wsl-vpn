# wsl-vpn

This is a repository to script in the wrokaround for WSL2 connectivity over VPN based on [Keiichi Shimamura](https://github.com/sakai135/wsl-vpnkit) work.

The solution utilises [Docker's VPNKit](https://github.com/moby/vpnkit) and [Jeff Trotman's npiperelay](https://github.com/jstarks/npiperelay) to tunnel the connectivity

## Getting started

1. Clone the repo, in windows or WSL.
    - If you are currently on VPN, you can only clone from WSL1 or Windows. It doesn't matter where you put the repo, as it can be removed when done.
2. (Currently) if you are on VPN, you will have to install `socat` (and `unzip` and `isoinfo` for Option 1 below) before you can run the setup script.
    - Easy option: Get off of VPN
    - Or if you cannot (for example, always-on-VPN Corporate rules)
        1. You can convert to image to WSL1: Windows: `wsl --set-version {WSL_NAME} 1`
        2. Install these dependencies (e.g. `apt-get update; apt-get install socat unzip genisoinfo`)
        3. Convert it back to WSL2: Windows: `wsl --set-version {WSL_NAME} 2`
3. Run the setup script:
    - *Option 1:* The preferred option since it gurantees fresh copies of all the dependencies to run the tunnel.
        1. Install Docker Desktop on your windows machine.
        2. Run `sudo ./wsl-vpnkit-setup.sh` from within this folder in WSL
    - *Option 2:* If you prefer not to (or can't) install Docker on your Windows machine, you can have the script download the required files instead.
        1. `sudo ./wsl-vpnkit-setup.sh --no-docker`

Once everything is working and you are satisfied, you can feel free to remove the cloned repository; all relavent files have been installed (However, you cannot delete `C:\bin\` in Windows)

## Removal

In case you want to remove and/or re-install the wsl-vpn files, you can run:

1. In the cloned repo, run:
    - `sudo ./wsl-vpnkit-unsetup.sh`

## FAQ

1. What if I have multiple WSLs?
    - You only install WSL-VPN into one WSL2 distro. The rest of the distros will get working internet from the WSL-VPN distro.
    - The only caveat is that you must start the WSL-VPN distro everytime you restart your computer or "shutdown" or "terminate" the WSL-VPN distro.
    - Simply opening up a tab to the WSL-VPN distro starts and fixes all of the other WSL2 distros. You can close it as soon as you open it.
    - If you need to script starting WSL-VPN: `/mnt/c/Windows/System32/wsl.exe -d {WSL-VPN distro name} --user root service wsl-vpnkit start`

<!-- ACKNOWLEDGEMENTS -->
## Acknowledgements
* [wsl-vpnkit](https://github.com/sakai135/wsl-vpnkit)
* [vpn-kit](https://github.com/moby/vpnkit)
* [npiperelay](https://github.com/jstarks/npiperelay)
