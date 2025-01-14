#!/bin/bash

# Detects all SSDs and displays their endurance attributes in human-readable format.

# Requires smartmontools: sudo apt-get install smartmontools 

# Download from:
# https://www.dropbox.com/sh/khfxfpu3k9170v0/AADSkNTFjw06JO029SrLRh70a?dl=0
# paminof@gmail.com


function HoursToYDH {
  local T=$1
  local Y=$((T/((24*365))))
  local D=$((T%((24*365))/24))
  local H=$((T%24))
  (( $Y > 0 )) && printf '%d years ' $Y
  (( $D > 0 )) && printf '%d days ' $D
  (( $H > 0 )) && printf '%d hours ' $H
}

LANG=C
BYTES_PER_MB=1048576
BYTES_PER_GB=1073741824
BYTES_PER_TB=1099511627776

# Get SSD Smart Data and pack into array.
for DISK in /sys/block/* ; do
	if [[ ${DISK} != *"zd"* ]]; then	# excluding ZFS volumes
	if [[ $(cat $DISK/queue/rotational) -eq 0 ]] ; then	# SSD=0 HD=1
		DEV=${DISK##*/}
		DEV=${DEV//nvme0n1/nvme0}   #Fix for MyDigitalSSD SBX
		# Get SMART attributes
		SMART_INFO="$(smartctl -a /dev/$DEV)"
		# Device column #1
		LIST_ITEMS+=("/dev/$DEV")
		# Get model name, trim leading whitespace
		if [ "${DEV:0:4}" = "nvme" ]; then	# Non-Volatile Memory express (NVMe)
			DEVICE_MODEL="$(grep "Model Number:" <<< "$SMART_INFO" | cut -d ":" -f 2 | sed -e 's/^[ \t]*//')"
		else
			DEVICE_MODEL="$(grep "Device Model:" <<< "$SMART_INFO" | cut -d ":" -f 2 | sed -e 's/^[ \t]*//')"
		fi
		# Model column #2
		LIST_ITEMS+=("$DEVICE_MODEL")

		case "$DEVICE_MODEL" in

			Samsung*) # Includes all models, matching pattern any starting with "Samsung", e.g. "Samsung SSD 850 PRO 128GB"
				if [ "${DEV:0:4}" = "nvme" ]; then	# Non-Volatile Memory express (NVMe)
					ATTR_POHR="Power On Hours:"
					ATTR_LBAW="Data Units Written:"
					ATTR_WEAR="Percentage Used:"
					LBA_SIZE=512
				else
					# Get attributes 9, 177, 241
					ATTR_POHR="Power_On_Hours"
					ATTR_LBAW="Total_LBAs_Written"
					ATTR_WEAR="Wear_Leveling_Count"
					LBA_SIZE=512
				fi
			;;

			"OCZ-VERTEX460")	# Firmware Version: 1.0
				# Get attributes 9, 233, ___
				ATTR_POHR="Power_On_Hours"
				ATTR_LBAW="249 Unknown_Attribute"
				ATTR_WEAR="Media_Wearout_Indicator"
				LBA_SIZE=512
			;;

			"OCZ-VERTEX4") # Model Family: Indilinx Barefoot_2/Everest/Martini based SSDs, Firmware Version: 1.5
				# Get attributes 9, 233, ___
				ATTR_POHR="Power_On_Hours"
				ATTR_LBAW="Lifetime_Writes"
				ATTR_WEAR="Media_Wearout_Indicator"
				LBA_SIZE=512
			;;

			"SC2 M2 SSD") # MyDigitalSSD 128GB Super Cache 2, Firmware Version: S9FM02.3
				# Get attributes 9, ___, ___
				ATTR_POHR="Power_On_Hours"
				ATTR_LBAW="173 Unknown_Attribute"
				ATTR_WEAR="ATTRIBUTE_NAME"	# No Wear_Indicator
				LBA_SIZE=512
			;;

			MT-*) # KingSpec M2 SSD MT-series
				ATTR_POHR="Power_On_Hours"
				ATTR_LBAW="Total_LBAs_Written"
				ATTR_WEAR="ATTRIBUTE_NAME"	# No Wear_Indicator
				LBA_SIZE=512
			;;
			Q-*) # KingSpec SATA SSD Q-series
				ATTR_POHR="Power_On_Hours"
				ATTR_LBAW="Total_LBAs_Written"
				ATTR_WEAR="ATTRIBUTE_NAME"	# No Wear_Indicator
				LBA_SIZE=512
			;;
			P3-*) # KingSpec SATA SSD P3-series
				ATTR_POHR="Power_On_Hours"
				ATTR_LBAW="Total_LBAs_Written"
				ATTR_WEAR="ATTRIBUTE_NAME"	# No Wear_Indicator
				LBA_SIZE=512
			;;
			"HFS256G32MND-2200A") # SK hynix SATA SSDs  HFS256G32MND-2200A
				ATTR_POHR="Power_On_Hours"
				ATTR_LBAW="Total_Writes_GiB"
				ATTR_WEAR="Wear_Leveling_Count"
				LBA_SIZE=512
			;;
			TS*GSSD360S) # Transcend 360S SSDs
				ATTR_POHR="Power_On_Hours"
				ATTR_LBAW="Total_LBAs_Written"
				ATTR_WEAR="Wear_Leveling_Count"
				LBA_SIZE="33554432"             #Total LBAs written (each write unit = 32MB)
			;;
			TS*GSSD340) # Transcend 340 SSDs
				ATTR_POHR="Power_On_Hours"
				ATTR_LBAW="Total_LBAs_Written"
				ATTR_WEAR="ATTRIBUTE_NAME"	# No Wear_Indicator
				LBA_SIZE=512
			;;


			############ Add other SSD models here. ############

			"BRAND-MODEL")	# _________________________
				# Get attributes ___, ___, ___
				ATTR_POHR="Power_On_Hours"
				ATTR_LBAW="ATTRIBUTE_NAME"	# Default string if no usable attribute is available
				ATTR_WEAR="ATTRIBUTE_NAME"	# Default string if no usable attribute is available
				LBA_SIZE=512
			;;


			*)
				# Other unsupported device models
                                if [ "${DEV:0:4}" = "nvme" ]; then      # Non-Volatile Memory express (NVMe)
                                        ATTR_POHR="Power On Hours:"
                                        ATTR_LBAW="Data Units Written:"
                                        ATTR_WEAR="Percentage Used:"
					LBA_SIZE=512
				else
					for (( i=1; i<=5; i++)); do LIST_ITEMS+=("n/a"); done
					continue
                                fi

			;;
		esac


			if [ "${DEV:0:4}" = "nvme" ]; then	# Non-Volatile Memory express (NVMe)
				ON_TIME=$(grep "$ATTR_POHR" <<< "$SMART_INFO" | awk '{print $4}'|sed 's/[^0-9]*//g')
				LBAS_WRITTEN=$(grep "$ATTR_LBAW" <<< "$SMART_INFO" | awk '{print $4}'| sed 's/[^0-9]*//g')
				LBAS_WRITTEN=$(( $LBAS_WRITTEN * 1100 ))
			else
				ON_TIME=$(grep "$ATTR_POHR" <<< "$SMART_INFO" | awk '{print $10}')
				LBAS_WRITTEN=$(grep "$ATTR_LBAW" <<< "$SMART_INFO" | awk '{print $10}')
				if [ "$ATTR_LBAW" = "Total_Writes_GiB" ]; then
					LBAS_WRITTEN="$(( $LBAS_WRITTEN * $BYTES_PER_GB / $LBA_SIZE ))"
				fi
			fi

			BYTES_WRITTEN=$(bc <<< "$LBAS_WRITTEN * $LBA_SIZE")	# Convert LBAs to bytes
			GB_WRITTEN=$(bc <<< "scale=3; $BYTES_WRITTEN / $BYTES_PER_GB")
			TB_WRITTEN=$(bc <<< "scale=3; $BYTES_WRITTEN / $BYTES_PER_TB")

			# Total data written: TB column #3
			LIST_ITEMS+=("$(sed ':a;s/\B[0-9]\{3\}\>/,&/;ta' <<< "$TB_WRITTEN")")
			# Mean write rate: GB/day, column #4
			LIST_ITEMS+=("$(bc <<< "scale=3; $GB_WRITTEN / $ON_TIME * 24" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')")

			if [ "${DEV:0:4}" = "nvme" ]; then	# Non-Volatile Memory express (NVMe)
				# Drive health column #5
				LIST_ITEMS+=("$(( 100 - $(grep "$ATTR_WEAR" <<< "$SMART_INFO" | awk '{print $3}' | cut -d"%" -f1) )) %")
				# P/E cycles column #6
				LIST_ITEMS+=("n/a")
			else
				# Drive health column #5
				LIST_ITEMS+=("$(grep "$ATTR_WEAR" <<< "$SMART_INFO" | awk '{print $4}' | sed 's/^0*//') %")
				# P/E cycles column #6
				LIST_ITEMS+=("$(grep "$ATTR_WEAR" <<< "$SMART_INFO" | awk '{print $10}' | sed 's/^0*//')")
			fi

			# Power ON time column #7
			LIST_ITEMS+=("$(HoursToYDH $ON_TIME)")
	fi
	fi
done

# Print all array elements in columns. To append to log: $0 >> ssd-endurance.log
COLS=7	# Number of columns
PAD=4	# Space between columns
echo -e "\n**** $(date +%c) ****"

for ((i=0; i<$COLS; i++)); do MAX[$i]=1; done	# Initialize MAX array to 1

for ((i=0; i<${#LIST_ITEMS[@]}; i++)); do	# Get length of longest string in each column
	[ ${#LIST_ITEMS[$i]} -gt ${MAX[$((i%$COLS))]} ] && MAX[$((i%$COLS))]=${#LIST_ITEMS[$i]}			# Pack into MAX array
#	echo "Col=$((i%$COLS)) Len=${#LIST_ITEMS[$i]} Max=${MAX[$((i%$COLS))]} \"${LIST_ITEMS[$i]}\""	# Debug
done
#printf '%s' "MAX="; for ((i=0; i<$COLS; i++)); do printf '%s ' ${MAX[$i]}; done; printf "%s\n"	# Debug, longest string per column

HEADERS=( "Device" "Model" "TB" "GB/day" "Health" "P/E" "Power On" )	# Initialize header array
# Print column headers left-aligned & space-padded to MAX[]+$PAD
for ((i=0; i<$COLS; i++)); do printf '%-*s' $((${MAX[$i]}+$PAD)) "${HEADERS[$i]}"; done; printf "%s\n"

for ((i=0; i<${#LIST_ITEMS[@]}; i++)); do	# Print all columns left-aligned & space-padded to MAX[]+$PAD
	printf '%-*s' $((${MAX[$((i%$COLS))]}+$PAD)) "${LIST_ITEMS[$i]}"	# (or '%*s' for right-aligned)
	if [ $(($((i+1))%$COLS)) -eq 0 ]; then printf "%s\n"; fi			# new line every $COLS columns
done

## Display endurance attributes for all SSDs in column format.
#CHECKED=$(zenity --list --title="$(basename "$0")" --text="\
#<b>TB written:</b> Total lifetime data written, in Terabytes
#<b>GB/day:</b> Mean daily write rate, in Gigabytes
#<b>Drive health:</b> Estimated percent life remaining
#<b>P/E cycles:</b> Average # of program-erase cycles
#
#To display all Smart Data, select a device and press <b>OK</b>
#" --column="Device" --column="Model" --column="TB written" --column="GB/day" --column="Drive health" --column="P/E cycles" --column="Power On" \
#--print-column=1 --width=900 --height=500 -- "${LIST_ITEMS[@]}")
#
## Work around zenity bug, returns selection twice if user presses Enter on selection.
#CHECKED=$(cut -d "|" -f2 <<< "$CHECKED")
#
#if [ -z "$CHECKED" ]; then exit; fi	# if strlen 0 exit
#
##echo $CHECKED	# User selection
#
#sudo smartctl -a $CHECKED | zenity --text-info \
#									   --title="$(basename "$0") -- $CHECKED" \
#									   --font="Courier 10 Pitch Bold" \
#									   --width=1000 --height=600

if [[ $? -ne 0 ]]; then exit; fi

#exec "$0" "$@"	# Restart script with same parameters
