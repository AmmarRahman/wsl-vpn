# wsl-vpn

This is a repository to script in the wrokaround for WSL2 connectivity over VPN based on [Keiichi Shimamura](https://github.com/sakai135/wsl-vpnkit) work.

The solution utilises [Docker's VPNKit](https://github.com/moby/vpnkit) and [Jeff Trotman's npiperelay](https://github.com/jstarks/npiperelay) to tunnel the connectivity

## Getting started

Once you have pulled the repoistory into your WSL2 environment you have two options

### *Option 1:*

This is the preferred option since it gurantees fresh copies of all the dependencies to run the tunnel. 
1. Install Docker Desktop on your windows machine.
2. run `sudo ./wsl-vpn-setup.sh` from within this folder


### *Option 2:*    
If you prefer not to install Docker on your windows machine, you can run `sudo ./wsl-vpn-setup-no-docker.sh` which would download the required files.

## Removal

In case you want to remove or re-install the wsl-vpn files, you can run:

1. `sudo ./wsl-vpn-unsetup.sh`

<!-- ACKNOWLEDGEMENTS -->
## Acknowledgements
* [wsl-vpnkit](https://github.com/sakai135/wsl-vpnkit)
* [vpn-kit](https://github.com/moby/vpnkit)
* [npiperelay](https://github.com/jstarks/npiperelay)
