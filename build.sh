#!/bin/bash

TIMESTAMP=$(date +%s)

SUITE="bookworm"
BRANCH="stable"
DESKTOP="xfce"
USERNAME="Zlodej"
PASSWORD="ChangeMe"

# Check if running with sudo
if [ "$UID" -ne 0 ]; then
    echo "This program needs sudo rights."
    echo "Run it with 'sudo $0'"
    exit 1
fi

echo "cleaning build area..."
sleep 2
rm .config
rm .boot.img
rm .rootfs.img
rm .rootfs.tar
rm files/firmware/initrd.img
rm files/firmware/kernel_2712.img
rm -f files/kernel/*.zip
rm -rf .rootfs/
rm config/rootfs_size.txt

docker rmi rpi:latest


echo ""
read -p "Enter Password: " choice

    echo "PASSWORD=$choice" >> .config
clear
echo "Writing '.config'..."
while IFS='=' read -r key value; do
    case "$key" in
    	SUITE)
    		SUITE="$value"
    		;;
        DESKTOP)
            DESKTOP="$value"
            ;;
        ADDITIONAL)
            ADDITIONAL="$value"
            ;;
        USERNAME)
            USERNAME="$value"
            ;;
        PASSWORD)
            PASSWORD="$value"
            ;;
        *)
            ;;
    esac
done < .config
fi
clear
echo "------------------------------"
SUITE="bookworm"
BRANCH="bookworm"
DESKTOP="xfce"
USERNAME="Zlodej5"
PASSWORD="ChangeMe"
ADDITIONAL="no"
echo -ne "\033]0; Building kernel\007"

echo "0" > config/kernel_status
scripts/makekernel.sh ${BRANCH} &

echo "Building Docker image..."
sleep 1
docker build --build-arg "SUITE="$SUITE --build-arg "DESKTOP="$DESKTOP --build-arg "ADDITIONAL="$ADDITIONAL --build-arg "USERNAME="$USERNAME --build-arg "PASSWORD="$PASSWORD -t rpi:latest -f config/Dockerfile .

echo "---------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------"


mkdir -p .rootfs

while [[ "$(cat config/kernel_status)" != "1" ]]; do
	clear
    echo "Waiting for Kernel compilation..."
    sleep 10  
done

docker run -dit --rm --name rpicontainer rpi:latest /bin/bash

docker cp kernel*.zip rpicontainer:/
docker cp scripts/installkernel.sh rpicontainer:/
docker exec rpicontainer bash -c '/installkernel.sh kernel-*.zip'
docker exec rpicontainer rm -rf kernel-*.zip
docker exec rpicontainer rm /installkernel.sh
rm kernel-*.zip

docker cp rpicontainer:/boot/firmware/ files/
docker exec rpicontainer rm -rf /boot/firmware
docker exec rpicontainer bash -c 'mkdir -p /boot/firmware'

docker exec rpicontainer bash -c 'cp /boot/initrd.img-* /tmp/initrd.img'
docker cp rpicontainer:/tmp/initrd.img files/firmware/initrd.img
docker exec rpicontainer bash -c 'rm /tmp/initrd.img'

docker cp rpicontainer:/rootfs_size.txt config/
docker exec rpicontainer bash -c 'rm /rootfs_size.txt'

echo "Creating an empty boot image..."
dd if=/dev/zero of=.boot.img bs=1M count=512 status=progress
mkfs.vfat -n BOOT .boot.img -F 32 

echo "Creating an empty rootfs image..."
rootfs_size=$(cat config/rootfs_size.txt)
dd if=/dev/zero of=.rootfs.img bs=1M count=$((${rootfs_size} + 256)) status=progress
mkfs.ext4 -L rootfs .rootfs.img -F

mkdir -p .rootfs
mount .rootfs.img .rootfs/
sleep 2

echo "Extracting the rootfilesystem of the container..."
docker export -o .rootfs.tar rpicontainer
docker kill rpicontainer
echo "---------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------"
tar -xvf .rootfs.tar -C .rootfs/
sleep 1

mkdir -p .bootfs/
sleep 1

mount .boot.img .bootfs/
sleep 2

cp -r files/firmware/* .bootfs/
sleep 2

umount .rootfs/
umount .bootfs/
rm -rf .rootfs/
sleep 2

rm -rf linux/
rm -rf .rootfs
rm -rf .bootfs
fsck -f .boot.img
e2fsck -f .rootfs.img
resize2fs -M .rootfs.img
sleep 1
    if [ "$DESKTOP" == "none "]; then
        DESKTOP="CLI"
    fi
mkdir -p output

TIMESTAMP=$(date +%s)
echo $TIMESTAMP > .TIMESTAMP

TMP=$(cat .TIMESTAMP)
boot_image=".boot.img"
root_image=".rootfs.img"
image_name="output/Debian-${SUITE}-${DESKTOP}-build-${TMP}.img"
reserved_spaceMB=2
boot_sizeMB=$((($(stat -c %s ${boot_image}) / 1024 / 1024)))
root_sizeMB=$((($(stat -c %s ${root_image}) / 1024 / 1024)))
image_sizeMB=$((boot_sizeMB + root_sizeMB + reserved_spaceMB))
start_part2=$((0 + boot_sizeMB))

dd if=/dev/zero of=$TMP bs=1M count=$image_sizeMB

loop_device=$(sudo losetup -f --show $TMP)

sudo parted --script $loop_device mktable msdos

sudo parted -a optimal $loop_device mkpart primary fat32 2MB ${boot_sizeMB}MB
sudo parted -a optimal $loop_device mkpart primary ext4 ${start_part2}MB 100%
sudo partprobe $loop_device

sleep 1

# Formatieren Sie die Partitionen mit den gewünschten Dateisystemen
sudo mkfs.vfat ${loop_device}p1 -n BOOT -F 32
sudo mkfs.ext4 ${loop_device}p2 -L rootfs -F

sleep 1

sudo fsck -f -y ${loop_device}p1
sudo e2fsck -f -y ${loop_device}p2
sudo partprobe $loop_device

sleep 1

# Mount-Verzeichnisse erstellen
sudo mkdir -p loop loop/1 loop/2 loop/boot loop/root


sleep 1

# Mounten Sie die neu erstellten Partitionen
sudo mount ${loop_device}p1 loop/1
sudo mount ${loop_device}p2 loop/2
sudo mount $boot_image loop/boot
sudo mount $root_image loop/root

sleep 1

# Kopieren Sie den Inhalt der Quellpartitionen in die neu erstellten Partitionen
sudo cp -r loop/boot/* loop/1
sudo cp -r loop/root/* loop/2


sleep 1

# Demounten Sie die neu erstellten Partitionen
sudo umount loop/1
sudo umount loop/2
sudo umount loop/root
sudo umount loop/boot

sleep 1

# Entfernen Sie die Mount-Verzeichnisse
sudo rm -rf loop

# Erstelle das kombinierte Image
echo "---------------------------"
echo "Creating the final image..."
echo "---------------------------"

sudo dd if=$loop_device of=$image_name bs=1M conv=noerror status=progress

sleep 1

rm $TMP
rm .TIMESTAMP
# Entfernen Sie die Loopback-Geräte
sudo losetup -d $loop_device
fi
exit 0
