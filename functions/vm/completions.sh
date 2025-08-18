add_completions() {
  kubectl completion bash > /etc/bash_completion.d/kubectl.sh
  helm completion bash > /etc/bash_completion.d/helm.sh
  echo "alias k='kubectl'" >> /etc/bash.bashrc
}
