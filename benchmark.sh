#!/bin/bash
# =============================================================================
# Storage Benchmark Script
# Usage:
#   Raw device:   sudo ./benchmark.sh /dev/sda
#   RAID array:   sudo ./benchmark.sh /dev/md0
#   Mount point:  sudo ./benchmark.sh /mnt/lustre
# =============================================================================

TARGET="$1"
RESULTS_DIR="./benchmark_results"
SIZE="4G"
RUNTIME=60

if [ -z "$TARGET" ]; then
    echo "Usage: $0 <device or mount point>"
    echo "  Examples:"
    echo "    sudo $0 /dev/sda          # raw drive"
    echo "    sudo $0 /dev/md0          # RAID array"
    echo "    sudo $0 /mnt/lustre       # Lustre mount point"
    exit 1
fi

if [ -b "$TARGET" ]; then
    MODE="device"
    LABEL=$(basename "$TARGET")
    FIO_TARGET="--filename=$TARGET"
elif [ -d "$TARGET" ]; then
    MODE="filesystem"
    LABEL=$(echo "$TARGET" | tr '/' '_' | sed 's/^_//')
    FIO_TARGET="--directory=$TARGET"
else
    echo "Error: $TARGET is not a block device or directory."
    exit 1
fi

mkdir -p "$RESULTS_DIR"
OUTFILE="$RESULTS_DIR/${LABEL}_$(date +%Y%m%d_%H%M%S).txt"

run_fio() {
    local RW="$1"
    local BS="$2"
    local JOBS="$3"

    fio --name=test \
        $FIO_TARGET \
        --rw="$RW" \
        --bs="$BS" \
        --size="$SIZE" \
        --direct=1 \
        --numjobs="$JOBS" \
        --ioengine=libaio \
        --iodepth=32 \
        --runtime="$RUNTIME" \
        --time_based \
        --group_reporting \
        --output-format=normal \
        2>/dev/null
}

extract_bw() {
    grep -E "^\s+(read|write):" | grep -oP '\(\K[0-9.]+(?=MB/s)' | head -1
}

extract_iops() {
    grep -E "^\s+(read|write):" | grep -oP 'IOPS=\K[0-9.]+[k]?' | head -1
}

print_result() {
    local LABEL="$1"
    local VALUE="$2"
    local UNIT="$3"
    printf " %-35s %12s %s\n" "$LABEL" "$VALUE" "$UNIT" | tee -a "$OUTFILE"
}

{
echo "============================================="
echo " Storage Benchmark"
echo " Target : $TARGET ($MODE)"
echo " Date   : $(date)"
echo "============================================="
echo ""
printf " %-35s %15s\n" "Test" "Result"
echo " --------------------------------------------------"
} | tee "$OUTFILE"

echo " Running sequential write (1 job)..." >&2
RESULT=$(run_fio write 1M 1)
print_result "Sequential Write (1 job)" "$(echo "$RESULT" | extract_bw)" "MB/s"

echo " Running sequential read (1 job)..." >&2
RESULT=$(run_fio read 1M 1)
print_result "Sequential Read  (1 job)" "$(echo "$RESULT" | extract_bw)" "MB/s"

echo " Running random write (1 job)..." >&2
RESULT=$(run_fio randwrite 4K 1)
print_result "Random Write     (1 job)" "$(echo "$RESULT" | extract_iops)" "IOPS"

echo " Running random read (1 job)..." >&2
RESULT=$(run_fio randread 4K 1)
print_result "Random Read      (1 job)" "$(echo "$RESULT" | extract_iops)" "IOPS"

echo "" | tee -a "$OUTFILE"

echo " Running sequential write (4 jobs)..." >&2
RESULT=$(run_fio write 1M 4)
print_result "Sequential Write (4 jobs)" "$(echo "$RESULT" | extract_bw)" "MB/s"

echo " Running sequential read (4 jobs)..." >&2
RESULT=$(run_fio read 1M 4)
print_result "Sequential Read  (4 jobs)" "$(echo "$RESULT" | extract_bw)" "MB/s"

echo " Running random write (4 jobs)..." >&2
RESULT=$(run_fio randwrite 4K 4)
print_result "Random Write     (4 jobs)" "$(echo "$RESULT" | extract_iops)" "IOPS"

echo " Running random read (4 jobs)..." >&2
RESULT=$(run_fio randread 4K 4)
print_result "Random Read      (4 jobs)" "$(echo "$RESULT" | extract_iops)" "IOPS"

{
echo ""
echo "============================================="
echo " Results saved to: $OUTFILE"
echo "============================================="
} | tee -a "$OUTFILE"
