# Configuration PCI Passthrough Script

## Description

Ce script est conçu pour configurer automatiquement un environnement **PCI Passthrough** sur une machine Linux, en prenant en charge les GPU de générations anciennes et récentes (par exemple, GT720 et RTX 4060). Il configure également les options GRUB, les modules VFIO, et blackliste les pilotes graphiques conflictuels pour assurer une compatibilité maximale.

### Fonctionnalités principales :
- Détection automatique du fabricant du CPU (AMD ou Intel).
- Configuration dynamique des options GRUB adaptées au matériel (ancien ou récent).
- Blacklist des pilotes graphiques conflictuels : `nouveau`, `nvidia`, `amdgpu`, `radeon`.
- Chargement des modules VFIO nécessaires pour le passthrough : `vfio`, `vfio_iommu_type1`, `vfio_pci`, `vfio_virqfd`.
- Identification des IDs PCI pour le GPU et l’audio HDMI associé.
- Gestion des options spécifiques aux anciennes cartes graphiques (comme `nomodeset` et `nouveau.modeset=0`).

## Prérequis

- **Accès root** : Ce script doit être exécuté en tant qu'utilisateur root.
- **Système d'exploitation** : Debian ou une distribution compatible avec **Proxmox**.
- **Support IOMMU** : Assurez-vous que votre carte mère et processeur prennent en charge IOMMU (activable dans le BIOS/UEFI).

## Installation

### Étapes :
1. Téléchargez ou copiez le script dans un fichier local, par exemple :
   ```bash
   nano Pci_Passthrough.sh
   ```
   Collez le contenu du script et enregistrez.

2. Donnez les permissions d'exécution au script :
   ```bash
   chmod +x Pci_Passthrough.sh
   ```

3. Exécutez le script en tant que root :
   ```bash
   sudo ./Pci_Passthrough.sh
   ```

## Détails des actions effectuées par le script

### 1. Configuration de GRUB
- Ajout des options nécessaires pour activer IOMMU et éviter les conflits graphiques :
  - Pour les anciens GPU : `nomodeset nouveau.modeset=0`.
  - Options génériques pour le PCI passthrough : `iommu=pt`.

### 2. Chargement des modules VFIO
- Ajout des modules suivants dans `/etc/modules` :
  - `vfio`
  - `vfio_iommu_type1`
  - `vfio_pci`
  - `vfio_virqfd`

### 3. Blacklist des pilotes graphiques conflictuels
- Les pilotes suivants sont blacklistés dans `/etc/modprobe.d/blacklist.conf` :
  - `nouveau`
  - `nvidia`
  - `amdgpu`
  - `radeon`

### 4. Détection des IDs PCI
- Identification des IDs PCI pour :
  - Le GPU.
  - L’audio HDMI associé au GPU.
- Ajout des IDs détectés dans `/etc/modprobe.d/vfio.conf`.

### 5. Mise à jour des fichiers système
- Mise à jour de GRUB avec `update-grub`.
- Régénération de l’initramfs avec `update-initramfs -u`.

### 6. Redémarrage
- Redémarrage automatique du système pour appliquer toutes les modifications.

## Exemple de sortie

Lors de l’exécution, le script affiche des informations détaillées :
```
--- Configuration PCI passthrough appliquée avec succès ---
Options GRUB : quiet amd_iommu=on iommu=pt nomodeset nouveau.modeset=0
Modules VFIO ajoutés : vfio, vfio_iommu_type1, vfio_pci, vfio_virqfd
Modules blacklistés : nouveau, nvidia, amdgpu, radeon
IDs PCI configurés pour VFIO : 10de:1f02,10de:10f9
Le système va redémarrer dans 10 secondes pour appliquer les changements.
```

## Démarrage en mode debug

Si vous rencontrez des problèmes au démarrage, vous pouvez démarrer le système en mode debug pour obtenir un maximum de logs :

1. Éditez les options de boot dans GRUB :
   - Lors du démarrage, appuyez sur la touche `e` pour modifier les paramètres de boot.

2. Ajoutez les options suivantes à la fin de la ligne commençant par `linux` :
   ```
   debug systemd.log_level=debug systemd.log_target=console
   ```

3. Appuyez sur `Ctrl+X` ou `F10` pour démarrer avec ces options.

4. Une fois le système démarré, les logs détaillés seront affichés directement dans la console ou accessibles via :
   ```bash
   journalctl -b --no-pager
   ```

## Dépannage

1. **Le GPU n’apparaît pas dans la VM :**
   - Assurez-vous que la carte graphique et ses périphériques associés (audio HDMI) sont dans le même groupe IOMMU :
     ```bash
     find /sys/kernel/iommu_groups/ -type l
     ```

2. **Problèmes au démarrage :**
   - En cas de problème graphique, essayez de démarrer en mode recovery et vérifiez les options GRUB :
     ```bash
     nano /etc/default/grub
     ```

3. **Logs VFIO :**
   - Vérifiez les logs pour confirmer que le GPU est attaché à VFIO :
     ```bash
     dmesg | grep -i vfio
     ```

## Contributions

Les contributions sont les bienvenues ! Si vous avez des suggestions ou des améliorations, n’hésitez pas à ouvrir une issue ou soumettre une pull request.

## Licence

Ce script est sous licence MIT. Vous êtes libre de l’utiliser, de le modifier et de le distribuer.
