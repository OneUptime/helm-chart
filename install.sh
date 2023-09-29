# Important: 
# This script will setup MicroK8s and install OneUptime on it. 
# This is used to install OneUptime on a standalone VM
# This is usally used for CI/CD testing, and to update VM's on GCP, Azure and AWS. 

# If this is the first install, then helm wont be found. 
if [[ ! $(which helm) ]]
then
    echo "RUNNING COMMAND:  sudo rm /etc/apt/sources.list  || echo 'File not found'"
    sudo rm /etc/apt/sources.list  || echo 'File not found'
    echo "RUNNING COMMAND:  sudo rm -rf /etc/apt/sources.list.d  || echo 'File not found'"
    sudo rm -rf /etc/apt/sources.list.d  || echo 'File not found'
    echo "RUNNING COMMAND:  sudo touch /etc/apt/sources.list || echo 'File already exists'"
    sudo touch /etc/apt/sources.list || echo 'File already exists'
    echo "RUNNING COMMAND:  sudo mkdir /etc/apt/sources.list.d || echo 'Dir already exists'"
    sudo mkdir /etc/apt/sources.list.d || echo 'Dir already exists'

    # Install Basic Repos
    echo "RUNNING COMMAND:  sudo apt-add-repository main"
    sudo apt-add-repository main
    echo "RUNNING COMMAND:  sudo apt-add-repository universe"
    sudo apt-add-repository universe
    echo "RUNNING COMMAND:  sudo apt-add-repository multiverse"
    sudo apt-add-repository multiverse
    echo "RUNNING COMMAND:  sudo apt-add-repository restricted"
    sudo apt-add-repository restricted

    # Install Basic packages
    echo "RUNNING COMMAND:  sudo apt-get update -y && sudo apt-get install -y curl bash git python openssl sudo apt-transport-https ca-certificates gnupg-agent software-properties-common systemd wget"
    sudo apt-get update -y && sudo apt-get install -y curl bash git python openssl sudo apt-transport-https ca-certificates gnupg-agent software-properties-common systemd wget

    # Install JQ, a way for bash to interact with JSON
    echo "RUNNING COMMAND: sudo apt-get install -y jq"
    sudo apt-get install -y jq

    # Install jsonpath, a way for bash to interact with JSON
    echo "RUNNING COMMAND: sudo apt-get install -y python-jsonpath-rw"
    sudo apt-get install -y python-jsonpath-rw
fi

if [[ ! -n $DOMAIN ]]; then
    DOMAIN=test.com
fi

if [[ ! -n $DKIM_PRIVATE_KEY ]]; then
    # create private key and public key
    echo "Setup private and public key"
    openssl genrsa -out private 2048
    chmod 0400 private
    openssl rsa -in private -out public -pubout
    # value of DKIM dns record
    echo "DKIM DNS TXT Record"
    echo "DNS Selector: oneuptime._domainkey"
    echo "DNS Value: v=DKIM1;p=$(grep -v '^-' public | tr -d '\n')"
    DKIM_PRIVATE_KEY=$(cat private | base64)
fi

if [[ ! -n $TLS_KEY ]] && [[ ! -n $TLS_CERT ]]; then
    # generate tls_cert.pem and tls_key.pem files with there keys
    echo "Setup tls_cert and tls_key"
    openssl req -x509 -nodes -days 2190 -newkey rsa:2048 -keyout tls_key.pem -out tls_cert.pem -subj "/C=US/ST=Massachusetts/L=Boston/O=Hackerbay/CN=$DOMAIN"
    # Encode your tls to base64 and export it
    TLS_KEY=$(cat tls_key.pem | base64)
    TLS_CERT=$(cat tls_cert.pem | base64)
fi

#Install Docker and setup registry and insecure access to it.
if [[ ! $(which docker) ]]
then
    echo "RUNNING COMMAND: curl -sSL https://get.docker.com/ | sh"
    curl -sSL https://get.docker.com/ | sh
    echo "RUNNING COMMAND: sudo systemctl restart docker"
    sudo systemctl restart docker
fi

#Install Docker and setup registry and insecure access to it.
if [[ ! $(which kubectl) ]]
then
    #Install Kubectl
    OS_ARCHITECTURE="amd64"
    if [[ "$(uname -m)" -eq "aarch64" ]] ; then OS_ARCHITECTURE="arm64" ; fi
    if [[ "$(uname -m)" -eq "arm64" ]] ; then OS_ARCHITECTURE="arm64" ; fi
    echo "RUNNING COMMAND: curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/$(OS_ARCHITECTURE)/kubectl"
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/$(OS_ARCHITECTURE)/kubectl
    echo "RUNNING COMMAND: chmod +x ./kubectl"
    chmod +x ./kubectl
    echo "RUNNING COMMAND: sudo mv ./kubectl /usr/local/bin/kubectl"
    sudo mv ./kubectl /usr/local/bin/kubectl
fi

if [[ ! $(which microk8s) ]]
then
    # Iptables
    echo "RUNNING COMMAND: sudo iptables -P FORWARD ACCEPT"
    sudo iptables -P FORWARD ACCEPT
    # Install microK8s
    echo "RUNNING COMMAND: sudo snap set system refresh.retain=2"
    sudo snap set system refresh.retain=2
    echo "RUNNING COMMAND: sudo snap install microk8s --classic"
    sudo snap install microk8s --classic
    echo "RUNNING COMMAND: sudo usermod -a -G microk8s $USER"
    sudo usermod -a -G microk8s $USER || echo "microk8s group not found"
    echo "RUNNING COMMAND: sudo microk8s.start"
    sudo microk8s.start
    echo "RUNNING COMMAND: sudo microk8s.status --wait-ready"
    sudo microk8s.status --wait-ready
    echo "RUNNING COMMAND: sudo microk8s.enable registry"
    sudo microk8s.enable registry
    echo "RUNNING COMMAND: sudo microk8s.enable dns"
    sudo microk8s.enable dns
    # If its a CI install, then do not enable storage. 
    if [[ "$1" != "ci-install" ]]
    then
        echo "RUNNING COMMAND: sudo microk8s.enable storage"
        sudo microk8s.enable storage
    fi
    echo "RUNNING COMMAND: sudo microk8s.inspect"
    sudo microk8s.inspect
    echo "Sleeping for 30 seconds"
    sleep 30s
fi

if [[ ! $(which k) ]]
then
    # Making 'k' as an alias to microk8s.kubectl
    echo "RUNNING COMMAND: sudo snap alias microk8s.kubectl k"
    sudo snap alias microk8s.kubectl k
    echo "RUNNING COMMAND: sudo chown -R $USER $HOME/.kube"
    sudo chown -R $USER $HOME/.kube
    echo "RUNNING COMMAND: sudo chmod 777 $HOME/.kube"
    sudo chmod 777 $HOME/.kube
    echo "RUNNING COMMAND: microk8s.kubectl config view --raw > $HOME/.kube/config"
    sudo microk8s.kubectl config view --raw > $HOME/.kube/config
    #Kubectl version.
    echo "RUNNING COMMAND: sudo k version"
    sudo k version
fi

if [[ ! $(which helm) ]]
then
    # Install helm
    sudo curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | sudo bash
fi


AVAILABLE_VERSION=$(curl https://oneuptime.com/api/version | jq '.server' | tr -d '"')
AVAILABLE_VERSION_BUILD=$(echo $AVAILABLE_VERSION | tr "." "0")

IMAGE_VERSION=$(sudo k get deployment fi-accounts -o=jsonpath='{$.spec.template.spec.containers[:1].image}' || echo 0) 

if [[ $IMAGE_VERSION -eq 0 ]]
then
    DEPLOYED_VERSION_BUILD=0
else
    SPLIT_STRING=(${IMAGE_VERSION//:/ })
    DEPLOYED_VERSION=$(echo ${SPLIT_STRING[1]})
    DEPLOYED_VERSION_BUILD=$(echo $DEPLOYED_VERSION | tr "." "0")
fi

if [[ $AVAILABLE_VERSION_BUILD -le $DEPLOYED_VERSION_BUILD ]]
then
    # If no updates are found then exit. 
    echo "No Updates found"
    exit 0
fi

# Install cluster with Helm.
sudo helm repo add oneuptime https://oneuptime.com/chart || echo "OneUptime already added"
sudo helm repo update


function updateinstallation {
    sudo k delete job oneuptime-InitScript || echo "InitScript already deleted"
    sudo helm upgrade --reuse-values fi oneuptime/OneUptime \
        --set image.tag=$AVAILABLE_VERSION
}


if [[ "$1" == "thirdPartyBillingEnabled" ]] #If thirdPartyBillingIsEnabled (for ex for Marketplace VM's)
then
    if [[ $DEPLOYED_VERSION_BUILD -eq 0 ]]
    then   
        if [[ "$2" == "aws-ec2" ]]
        then
            # 169.254.169.254 is a static AWS service which amazon uses to get instance id
            # https://forums.aws.amazon.com/thread.jspa?threadID=100982
            INSTANCEID=`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`

            # Chart not deployed. Create a new deployment. Set service of type nodeport for VM's. 
            # Add Admin Email and Password on AWS.
            sudo helm install fi oneuptime/OneUptime \
            --set isThirdPartyBilling=true \
            --set nginx-ingress-controller.service.type=NodePort \
            --set nginx-ingress-controller.hostNetwork=true \
            --set image.tag=$AVAILABLE_VERSION \
            --set oneuptime.admin.email=admin@admin.com \
            --set disableSignup=true \
            --set oneuptime.admin.password=$INSTANCEID 
            
        else
            # Chart not deployed. Create a new deployment. Set service of type nodeport for VM's. This is used for Azure and AWS.
            sudo helm install fi oneuptime/OneUptime \
            --set isThirdPartyBilling=true \
            --set nginx-ingress-controller.service.type=NodePort \
            --set nginx-ingress-controller.hostNetwork=true \
            --set image.tag=$AVAILABLE_VERSION 
        fi
    else
        updateinstallation
    fi
elif [[ "$1" == "ci-install" ]] # If its a local install, take local scripts. 
then
    if [[ $DEPLOYED_VERSION_BUILD -eq 0 ]]
    then
        # install services.
        if [[ "$2" == "enterprise" ]]
        then
            sudo helm install -f ./kubernetes/values-enterprise-ci.yaml fi ./HelmChart/public/oneuptime \
            --set haraka.domain=$DOMAIN \
            --set haraka.dkimPrivateKey=$DKIM_PRIVATE_KEY \
            --set haraka.tlsCert=$TLS_CERT \
            --set haraka.tlsKey=$TLS_KEY
        else
            sudo helm install -f ./kubernetes/values-saas-ci.yaml fi ./HelmChart/public/oneuptime \
            --set haraka.domain=$DOMAIN \
            --set haraka.dkimPrivateKey=$DKIM_PRIVATE_KEY \
            --set haraka.tlsCert=$TLS_CERT \
            --set haraka.tlsKey=$TLS_KEY
        fi
    else
        sudo k delete job oneuptime-InitScript || echo "InitScript already deleted"
        sudo helm upgrade --reuse-values fi ./HelmChart/public/oneuptime
    fi
else
    if [[ $DEPLOYED_VERSION_BUILD -eq 0 ]]
    then
        # set service of type nodeport for VM's.
        sudo helm install fi oneuptime/OneUptime \
        --set nginx-ingress-controller.service.type=NodePort \
        --set nginx-ingress-controller.hostNetwork=true \
        --set image.tag=$AVAILABLE_VERSION \
        --set haraka.domain=$DOMAIN \
        --set haraka.dkimPrivateKey=$DKIM_PRIVATE_KEY \
        --set haraka.tlsCert=$TLS_CERT \
        --set haraka.tlsKey=$TLS_KEY
    else
        updateinstallation
    fi
fi