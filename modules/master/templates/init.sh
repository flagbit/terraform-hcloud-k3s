#!/bin/bash

# install dependencies
apt-get -yq update
apt-get install -yq \
    ca-certificates \
    curl \
    ntp \
    jq

# functions
function getLatestTag {
  REPOSITORY=$1
  if [ $REPOSITORY ]; then
    curl -s https://api.github.com/repos/hetznercloud/$REPOSITORY/releases/latest|jq -r '.tag_name'
  fi
}

# k3s variables
export INSTALL_K3S_CHANNEL=${k3s_channel}
export K3S_TOKEN=${k3s_token}

# hcloud variables
HCLOUD_CCM_REPOSITORY=hcloud-cloud-controller-manager
HCLOUD_CCM_TAG=$(getLatestTag $HCLOUD_CCM_REPOSITORY)
HCLOUD_CSI_REPOSITORY=csi-driver
HCLOUD_CSI_TAG=$(getLatestTag $HCLOUD_CSI_REPOSITORY)

# install k3s
curl -sfL https://get.k3s.io | sh -s - \
    --flannel-backend=host-gw \
    --disable local-storage \
    --disable-cloud-controller \
    --disable traefik \
    --disable servicelb \
    --node-taint node-role.kubernetes.io/master:NoSchedule \
    --kubelet-arg 'cloud-provider=external'

# manifestos addons
while ! test -d /var/lib/rancher/k3s/server/manifests; do
    echo "Waiting for '/var/lib/rancher/k3s/server/manifests'"
    sleep 1
done

# install hetznercloud ccm
kubectl -n kube-system create secret generic hcloud --from-literal=token=${hcloud_token} --from-literal=network=${hcloud_network}
# Install latest cloud-controller-manager from hetzner.
# because we are also using "latest stable" k3s relase, we can assume that
# the latest git-tag from hetznercloud repository will be fine.
curl -sL \
  https://raw.githubusercontent.com/hetznercloud/$HCLOUD_CCM_REPOSITORY/$HCLOUD_CCM_TAG/deploy/ccm-networks.yaml \
  > /var/lib/rancher/k3s/server/manifests/hcloud-ccm.yaml

# install hetznercloud csi
kubectl -n kube-system create secret generic hcloud-csi --from-literal=token=${hcloud_token}
# Install latest container-storage-interface from hetzner.
# because we are also using "latest stable" k3s relase, we can assume that
# the latest git-tag from hetznercloud repository will be fine.
curl -sL \
  https://raw.githubusercontent.com/hetznercloud/$HCLOUD_CSI_REPOSITORY/$HCLOUD_CSI_TAG/deploy/kubernetes/hcloud-csi.yml \
  > /var/lib/rancher/k3s/server/manifests/hcloud-csi.yaml

