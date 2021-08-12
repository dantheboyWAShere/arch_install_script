#!/bin/sh
#-------------- UEFI or BIOS
if [ -d /sys/firmware/efi ];
	then
		sys=UEFI
	else 
		sys=BIOS
fi
#-------------- Prompts
printf "Which Partition/Drive Will The System Be Installed To?: [/dev/sdxx] " && read root
[[ $sys == UEFI ]] && printf "Which Partition Shall Be Used For The Bootloader?: [/dev/sdxx] " && read boot
printf "What Is Your Timezone?: [Country/City] " && read zone
printf "What Is Your Locale: [xx_XX] " && read locale
printf "Do You Want a Home Partition?: [y/n] " && read ans && [[ $ans == y ]] && printf '%s\n' "Which Partition" && read home || home=""
printf "What Is This System's Hostname? " && read host
printf "What Is This System's Root Password? " && read rt_passwd
printf "What Is Your Username For This New System? " && read username
printf "What Is Thew New User's Password? " && read passwd
#-------------- Mounting System
case $sys in
	UEFI)
		mount $root /mnt
		if [ -z "$home" ]
			then
				mkdir -p /mnt/boot
				mount $boot /mnt/boot
				mkdir -p /mnt/home/$username
			else 
				mkdir -p /mnt/boot
				mkdir -p /mnt/home
				mount $boot /mnt/boot
				mount $home /mnt/home
				mkdir -p /mnt/home/$username
		fi
	;;
	BIOS)
		mount $root /mnt
		if [ -z "$home" ]
			then
				return 0
			else
				mount $home
				mkdir -p /mnt/home/$username
		fi
	;;
esac
#-------------- Installing Core Packages
[[ $sys == UEFI ]] && pacstrap /mnt base base-devel linux linux-firmware neovim networkmanager grub efibootmgr || pacstrap /mnt base base-devel linux linux-firmware neovim networkmanager grub
#-------------- Configuring System
genfstab -LU /mnt >> /mnt/etc/fstab &&
arch-chroot /mnt &&
ln -sf /usr/share/zoneinfo/$zone /etc/localtime &&
sed -ie "s|^#${locale}|${locale}|g" locale.gen &&
locale-gen &&
touch /etc/locale.conf &&
echo "LANG=${locale}.UTF-8" >> /etc/locale.conf &&
echo "$host" >> /etc/hostname
echo "1270.0.0.1	localhost\n::1		localhost\n127.0.1.1		$host.localdomain $host"
systemctl enable NetworkManager.service && systemctl start NetworkManager.service
#-------------- Setting Up Bootloader (Grub)
[ $sys == UEFI ] && grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB || grub-install --target=i386-pc $(echo $boot | sed -e 's/[0-9]//g') 
grub-mkconfig -o /boot/grub/grub.cfg
#-------------- Setting Up Users and Root
useradd $username
echo "$passwd" | passwd --stdin "$username"
echo "$rt_passwd" | passwd --stdin
usermod -aG wheel "$username"
#-------------- Configurations


