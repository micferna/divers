#!/bin/bash

set -e  # Arrête le script dès qu'une commande échoue

# Vérifie si l'utilisateur est root
if [ "$EUID" -ne 0 ]; then
  echo "Veuillez exécuter ce script en tant que root."
  exit 1
fi

# Détecte le fabricant du CPU
CPU_VENDOR=$(lscpu | grep 'Vendor ID' | awk '{print $3}')

# Sélectionne l'option appropriée selon le fabricant du CPU
if [ "$CPU_VENDOR" == "AuthenticAMD" ]; then
  GRUB_OPTION_BASE="quiet amd_iommu=on iommu=pt kvm.ignore_msrs=1 nofb nomodeset video=vesafb:off initcall_blacklist=sysfb_init"
elif [ "$CPU_VENDOR" == "GenuineIntel" ]; then
  GRUB_OPTION_BASE="quiet intel_iommu=on iommu=pt kvm.ignore_msrs=1 nofb nomodeset video=vesafb:off initcall_blacklist=sysfb_init"
else
  echo "Fabricant de CPU non reconnu."
  exit 1
fi

# Détecte le modèle de GPU
GPU_MODEL=$(lspci | grep -i "VGA compatible controller" | awk -F': ' '{print $3}')

# Options spécifiques selon le modèle de GPU
if echo "$GPU_MODEL" | grep -qi "GT720"; then
  echo "GPU détecté : $GPU_MODEL (ancienne génération)"
  GRUB_OPTION="$GRUB_OPTION_BASE nouveau.modeset=0"
elif echo "$GPU_MODEL" | grep -qi "RTX"; then
  echo "GPU détecté : $GPU_MODEL (nouvelle génération)"
  GRUB_OPTION="$GRUB_OPTION_BASE"
else
  echo "GPU détecté : $GPU_MODEL (génération inconnue, utilisation des options génériques)"
  GRUB_OPTION="$GRUB_OPTION_BASE nouveau.modeset=0"
fi

# Vérifie si le fichier existe avant de le modifier
if [ ! -f /etc/default/grub ]; then
  echo "Le fichier /etc/default/grub n'existe pas."
  exit 1
fi

# Remplace ou ajoute la ligne GRUB_CMDLINE_LINUX_DEFAULT dans /etc/default/grub
if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
  sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*$|GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_OPTION\"|" /etc/default/grub
else
  echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_OPTION\"" >> /etc/default/grub
fi

# Met à jour grub
update-grub

# Ajoute les modules nécessaires au fichier /etc/modules
for module in vfio vfio_iommu_type1 vfio_pci vfio_virqfd; do
  if ! grep -q "$module" /etc/modules; then
    echo "$module" >> /etc/modules
  fi
done

# Blacklist des pilotes graphiques conflictuels
BLACKLIST_FILE="/etc/modprobe.d/blacklist.conf"
if [ ! -f "$BLACKLIST_FILE" ]; then
  touch "$BLACKLIST_FILE"
fi

for module in nouveau nvidia amdgpu radeon; do
  if ! grep -q "blacklist $module" "$BLACKLIST_FILE"; then
    echo "blacklist $module" >> "$BLACKLIST_FILE"
  fi
done

# Met à jour l'initramfs pour que les changements soient pris en compte
update-initramfs -u

# Ajoute l'option KVM pour ignorer les MSRs dans /etc/modprobe.d/kvm.conf
KVM_CONF="/etc/modprobe.d/kvm.conf"
echo "options kvm ignore_msrs=1 report_ignored_msrs=0" > "$KVM_CONF"

# Détecte les IDs PCI du GPU et de l'audio HDMI
GPU_IDS=$(lspci -nn | grep -E "VGA compatible controller|Audio device" | grep -oP '\\[\\K[^\\]]*' | tr '\\n' ',' | sed 's/,$//')

if [ -z "$GPU_IDS" ]; then
  echo "Aucun ID PCI de carte graphique ou audio HDMI trouvé."
  exit 1
fi

# Ajoute les IDs PCI au fichier vfio.conf
VFIO_CONF="/etc/modprobe.d/vfio.conf"
echo "options vfio-pci ids=$GPU_IDS" > "$VFIO_CONF"

# Affiche un résumé des modifications
echo -e "\\n--- Configuration PCI passthrough appliquée avec succès ---"
echo "Options GRUB : $GRUB_OPTION"
echo "Modules VFIO ajoutés : vfio, vfio_iommu_type1, vfio_pci, vfio_virqfd"
echo "Modules blacklistés : nouveau, nvidia, amdgpu, radeon"
echo "IDs PCI configurés pour VFIO : $GPU_IDS"

echo "Le système va redémarrer dans 10 secondes pour appliquer les changements."
sleep 10
reboot
