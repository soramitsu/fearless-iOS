command -v generamba >/dev/null 2>&1 || { echo "generamba is required to continue... Run gem install generamba " >&2; exit 1; }

generamba template install
generamba gen $1 "viper-code-layout"
