#!/bin/bash


PROJECT_DIR="/project"
BACKUP_ROOT="/backup"
DATE=$(date +%F)
BACKUP_DIR="$BACKUP_ROOT/backup_$DATE"


REPORT="report.txt"
LOG="cleanup.log"


mkdir -p "$BACKUP_DIR"
echo "===== Cleanup Report ($DATE) =====" > "$REPORT"
echo "===== Log Started ($DATE) =====" >> "$LOG"

MOVED=0
DELETED=0
ERRORS=0
SPACE_CLEARED=0

log() {
    echo "$(date '+%F %T') - $1" >> "$LOG"
}


AVAILABLE_SPACE=$(df "$BACKUP_ROOT" | awk 'NR==2 {print $4}')
if [ "$AVAILABLE_SPACE" -lt 102400 ]; then
    log "ERROR: Not enough space in /backup"
    echo "Backup aborted due to low disk space" >> "$REPORT"
    exit 1
fi


find "$PROJECT_DIR" -type f -mtime +30 ! -name "*.tmp" | while read FILE; do
    REL_PATH="${FILE#$PROJECT_DIR/}"
    DEST="$BACKUP_DIR/$REL_PATH"

    mkdir -p "$(dirname "$DEST")"

    
    if [ -f "$DEST" ]; then
        DEST="${DEST}_$(date +%s)"
    fi

    SIZE=$(du -k "$FILE" | cut -f1)

    if mv "$FILE" "$DEST" 2>>"$LOG"; then
        echo "Moved: $FILE -> $DEST" >> "$REPORT"
        log "Moved: $FILE"
        MOVED=$((MOVED + 1))
        SPACE_CLEARED=$((SPACE_CLEARED + SIZE))
    else
        log "ERROR moving: $FILE"
        echo "Permission/Error moving: $FILE" >> "$REPORT"
        ERRORS=$((ERRORS + 1))
    fi
done


find "$PROJECT_DIR" -type f -name "*.tmp" -mtime +7 | while read FILE; do
    SIZE=$(du -k "$FILE" | cut -f1)

    if rm -f "$FILE" 2>>"$LOG"; then
        echo "Deleted: $FILE" >> "$REPORT"
        log "Deleted: $FILE"
        DELETED=$((DELETED + 1))
        SPACE_CLEARED=$((SPACE_CLEARED + SIZE))
    else
        log "ERROR deleting: $FILE"
        echo "Permission/Error deleting: $FILE" >> "$REPORT"
        ERRORS=$((ERRORS + 1))
    fi
done


echo "" >> "$REPORT"
echo "Summary:" >> "$REPORT"
echo "Files moved: $MOVED" >> "$REPORT"
echo "Files deleted: $DELETED" >> "$REPORT"
echo "Total space cleared: ${SPACE_CLEARED} KB" >> "$REPORT"
echo "Errors: $ERRORS" >> "$REPORT"

log "Cleanup completed"
echo "===== Cleanup Completed =====" >> "$LOG"