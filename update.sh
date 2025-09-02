MY_REPO=exception7601/Analytics
BUILD_COMMIT=$(git log --oneline --abbrev=16 --pretty=format:"%h" -1)
JSON_FILE="Carthage/FirebaseAnalyticsBinary.json"
NEW_NAME=FirebaseAnalyticsBinary-${BUILD_COMMIT}.zip
NAME_FILE=FirebaseAnalyticsBinary.json
URL_CARTHAGE="https://dl.google.com/dl/firebase/ios/carthage/FirebaseAnalyticsBinary.json"

curl -L -o "$NAME_FILE" "$URL_CARTHAGE"
VERSION=$(jq -r 'keys | max_by(split(".") | map(tonumber))' $NAME_FILE)
URL_FRAMEWORK=$(jq -r --arg v "$VERSION" '.[$v]' "$NAME_FILE")

echo ${VERSION}

curl -L -o "$NEW_NAME" "$URL_FRAMEWORK"

SUM=$(swift package compute-checksum ${NEW_NAME} )
DOWNLOAD_URL="https://github.com/${MY_REPO}/releases/download/${VERSION}/${NEW_NAME}"

if [ ! -f $JSON_FILE ]; then
  echo "{}" > $JSON_FILE
fi

JSON_CARTHAGE="$(jq --arg version "${VERSION}" --arg url "${DOWNLOAD_URL}" '. + { ($version): $url }' $JSON_FILE)" 
echo $JSON_CARTHAGE > $JSON_FILE

NOTES=$(cat <<END
Carthage
\`\`\`
binary "https://raw.githubusercontent.com/${MY_REPO}/main/${JSON_FILE}"
\`\`\`

Install
\`\`\`
carthage bootstrap --use-xcframeworks
\`\`\`
END
)
echo "${NOTES}"

BUILD=$(date +%s)
NEW_VERSION=${VERSION}

# echo ${NEW_VERSION} > version
git add $JSON_FILE
git commit -m "new Version ${NEW_VERSION}"
git tag -s -a ${NEW_VERSION} -m "v${NEW_VERSION}"
# git checkout -b release-v${NEW_VERSION}
git push origin HEAD --tags

gh release create ${NEW_VERSION} ${NEW_NAME} --notes "${NOTES}"

