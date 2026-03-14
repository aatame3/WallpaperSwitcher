#!/bin/bash
# ビルドごとにUUIDベースのビルドIDを生成し、BuildID.swift に書き出す
BUILD_ID=$(uuidgen)
OUTPUT_FILE="${SRCROOT}/Sources/Generated/BuildID.swift"

mkdir -p "$(dirname "$OUTPUT_FILE")"

cat > "$OUTPUT_FILE" << EOF
// Auto-generated — do not edit
enum BuildInfo {
    static let buildID = "$BUILD_ID"
}
EOF
