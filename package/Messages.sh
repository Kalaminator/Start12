#!/bin/sh
# Extract strings into po/template.pot and merge into po/es.po
cd "$(dirname "$0")/.."
xgettext -L JavaScript --from-code=UTF-8 --keyword=i18n:1 --keyword=i18nc:1c,2 --keyword=i18np:1,2 \
  -o po/template.pot $(find package/contents -name '*.qml' -o -name '*.js' | sort)
[ -f po/es.po ] && msgmerge -U --backup=none po/es.po po/template.pot
