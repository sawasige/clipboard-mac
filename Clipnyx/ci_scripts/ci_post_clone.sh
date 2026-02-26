#!/bin/sh
set -e

if [ -n "$CI_TAG" ]; then
  VERSION="${CI_TAG#v}"
  PBXPROJ="${CI_PRIMARY_REPOSITORY_PATH}/Clipnyx/Clipnyx.xcodeproj/project.pbxproj"
  sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = ${VERSION};/" "$PBXPROJ"
  sed -i '' "s/CURRENT_PROJECT_VERSION = .*;/CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER};/" "$PBXPROJ"
  echo "Version: ${VERSION} (${CI_BUILD_NUMBER})"
fi
